import * as denoHttp from "https://deno.land/std@0.60.0/http/server.ts";
import * as path from "https://deno.land/std@0.60.0/path/mod.ts";
import { parse as parseFlags } from "https://deno.land/std@0.60.0/flags/mod.ts";
import { v4 as uuid } from "https://deno.land/std@0.60.0/uuid/mod.ts";
import { config } from "https://deno.land/x/dotenv/mod.ts";
import { Pool } from "https://deno.land/x/postgres@v0.4.0/mod.ts";

config({ safe: true });

const tempDirectoriesToRemove = [];
const requests = {};
let elmServer = null;
let serverInstance = null;
let databaseConnectionPool = null;
let defaultXhr = null;

async function main() {
  switch (Deno.args[0]) {
    case "start":
      {
        const [compiledElm, commnadLineArgs] = await compileElm();
        const [module, flags] = await buildModule(compiledElm, commnadLineArgs);
        runCompiledServer(module, flags);
      }
      break;
    case "--help":
      showHelp();
      break;
    default:
      console.log(
        `Run 'elm-server --help' for a list of commands or visit main.website.com`
      );
      exit(1);
      break;
  }
}

function showHelp() {
  console.log(`elm-server commands and options

--help   Displays this text
  start  Takes a source Elm file, an optional list of args, and starts the server`);
}

async function compileElm() {
  const sourceFileName = Deno.args[1];
  const commandLineArgs = Deno.args.slice(2);
  const absolutePath = path.resolve(sourceFileName);
  const extension = path.extname(absolutePath);

  if (extension === ".js") {
    return [absolutePath, commandLineArgs];
  } else if (extension === ".elm") {
    const tempDirectory = createTemporaryDirectory();
    const tempFileName = path.resolve(tempDirectory, "main.js");
    const elmFileDirectory = path.dirname(absolutePath);
    const elmProcess = Deno.run({
      cmd: [
        "elm",
        "make",
        // "--optimize", TODO: Uncomment this
        "--output=" + tempFileName,
        absolutePath,
      ],
      stdout: "piped",
      cwd: elmFileDirectory,
    });
    const elmResult = await elmProcess.status();

    if (elmResult.success) {
      return [tempFileName, commandLineArgs];
    } else {
      // The Elm compiler will have printed out a compilation error
      // message, no need to add our own
      exit(1);
    }
  } else {
    console.log(
      `Unrecognized source file extension ${extension} (expecting.elm or.js)`
    );
    exit(1);
  }
}

async function buildModule(jsFileName, commandLineArgs) {
  // Read compiled JS from file
  const jsData = Deno.readFileSync(jsFileName);
  const jsText = new TextDecoder("utf-8").decode(jsData);

  // Add our mock XMLHttpRequest class into the global namespace
  // so that Elm code will use it
  defaultXhr = globalThis["XMLHttpRequest"];
  globalThis["XMLHttpRequest"] = XMLHttpRequest;

  // Run Elm code to create the 'Elm' object
  const globalEval = eval;
  globalEval(jsText);

  // Collect flags to pass to Elm program
  const flags = {};
  flags["arguments"] = parseFlags(commandLineArgs);
  switch (Deno.build.os) {
    case "mac":
    case "darwin":
    case "linux":
      flags["platform"] = {
        type: "posix",
        name: Deno.build.os,
      };
      break;
    case "windows":
      flags["platform"] = { type: "windows" };
      break;
    default:
      console.log("Unrecognized OS '" + Deno.build.os + "'");
      exit(1);
  }
  flags["environment"] = Deno.env.toObject();
  // flags["workingDirectory"] = Deno.cwd();

  // Get Elm program object
  var module = findNestedModule(globalThis["Elm"]);
  while (!("init" in module)) {
    module = findNestedModule(module);
  }

  return [module, flags];
}

function exit(code) {
  // First, clean up any temp directories created while running the script
  for (const directoryPath of tempDirectoriesToRemove) {
    try {
      Deno.removeSync(directoryPath, { recursive: true });
    } catch (error) {
      // Ignore any errors that may occur when attempting to delete a
      // temporary directory - likely the directory was just deleted
      // explicitly, and even if it's some other issue (directory
      // somehow became read-only, in use because an antivirus program is
      // currently checking it etc.) it's not generally the end of the
      // world if the odd temp directory doesn't get deleted. (Script
      // authors who need to make sure sensitive data gets deleted can
      // always call Directory.obliterate in their script and check for
      // any errors resulting from it.)
      continue;
    }
  }

  if (serverInstance != null) {
    serverInstance.close();
  }

  // Finally, actually exit
  Deno.exit(code);
}

function createTemporaryDirectory() {
  // Create a new temp directory
  const directoryPath = Deno.makeTempDirSync();
  // Add it to the list of temp directories to remove when the script has
  // finished executing
  tempDirectoriesToRemove.push(directoryPath);
  return directoryPath;
}

function findNestedModule(obj) {
  const nestedModules = Object.values(obj);
  if (nestedModules.length != 1) {
    console.log(
      `Expected exactly 1 nested module, found ${nestedModules.length}`
    );
    exit(1);
  }
  return nestedModules[0];
}

function runCompiledServer(module, flags) {
  // Start Elm program
  // console.log("Debug", flags.environment);
  elmServer = module.init({ flags });
}

class XMLHttpRequest {
  constructor() {
    this.responseUrl = "/runner";
  }

  getAllResponseHeaders() {
    return "";
  }

  setRequestHeader(name, value) {
    return;
  }

  open(method, url, performAsync) {
    if (url === "internal:/runner") {
      return;
    } else {
      defaultXhr.open(method, url, performAsync);
    }
  }

  addEventListener(name, callback) {
    if (name == "load") {
      this._callback = callback;
    }
  }

  async send(request) {
    let xhr = this;
    function handleResponse({
      status = 200,
      body = "",
      statusText = "CONTINUE",
    } = {}) {
      xhr.status = status;
      xhr.statusText = statusText;
      xhr.response = JSON.stringify(body);
      xhr._callback();
    }
    console.log(request);
    request = JSON.parse(request);
    switch (request.msg) {
      case "SERVE":
        {
          const { databaseConnection, port, certs } = request.args;
          const options = { port };

          if (certs != null) {
            serverInstance = denoHttp.serveTLS({
              ...options,
              certFile: certs.certificatePath,
              keyFile: certs.keyPath,
            });
          } else {
            serverInstance = denoHttp.serve(options);
          }

          if (databaseConnection != null) {
            const POOL_CONNECTIONS = 20;
            const {
              hostname,
              port,
              user,
              password,
              database,
            } = databaseConnection;
            databaseConnectionPool = new Pool(
              {
                user,
                password,
                port,
                hostname,
                database,
              },
              POOL_CONNECTIONS
            );
          }

          setTimeout(function () {
            elmServer.ports.runnerMsg.send({ message: "SERVED", value: null });
            handleResponse();
          });

          for await (const req of serverInstance) {
            if (elmServer == null) {
              console.error(
                "Somehow started the server but lost the elm app runtime."
              );
              exit(1);
            } else {
              const nextId = uuid.generate();
              const decoder = new TextDecoder();
              const decodedBody = decoder.decode(await Deno.readAll(req.body));
              req.elmBody = decodedBody;
              requests[nextId] = req;
              elmServer.ports.requestPort.send({ req, id: nextId });
            }
          }
        }
        break;
      case "RESPOND":
        {
          console.log("requests", request.args.id);
          const req = requests[request.args.id];
          if (req != null) {
            const { headers, ...restOptions } = request.args.options;
            const actualHeaders = new Headers();

            headers.forEach(function ([key, val]) {
              actualHeaders.set(key, val);
            });

            req.respond({ ...restOptions, headers: actualHeaders });
            delete requests[request.args.id];
            handleResponse();
          } else {
            handleResponse();
          }
        }
        break;
      case "CLOSE":
        {
          serverInstance.close();
          elmServer.ports.runnerMsg.send({ message: "CLOSED", value: null });
          handleResponse();
        }
        break;
      case "PRINT":
        console.log(request.args);
        handleResponse();
        break;
      case "DATABASE_QUERY":
        {
          try {
            const client = await databaseConnectionPool.connect();
            const result = await client.query(request.args);

            client.release();
            handleResponse({
              body: result.rows,
            });
          } catch (err) {
            console.log("query error", err);
            handleResponse({
              status: 500,
              body: err,
            });
          }
        }
        break;
      case "FILE_SYSTEM_READ":
        {
          try {
            const decoder = new TextDecoder("utf-8");
            const fileContent = decoder.decode(
              await Deno.readFile(request.args)
            );
            handleResponse({
              body: fileContent,
            });
          } catch (error) {
            handleResponse({
              body: error,
              status: 500,
            });
          }
        }
        break;
      default:
        console.error(
          `Error: Unknown server request: "${request.msg}"`,
          request.args
        );
    }
  }
}

main();
