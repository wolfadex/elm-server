import * as denoHttp from "https://deno.land/std@0.60.0/http/server.ts";
import * as path from "https://deno.land/std@0.60.0/path/mod.ts";
import { parse as parseFlags } from "https://deno.land/std@0.60.0/flags/mod.ts";
import { config } from "https://deno.land/x/dotenv/mod.ts";
import { Pool } from "https://deno.land/x/postgres@v0.4.0/mod.ts";

config({ safe: true });

const tempDirectoriesToRemove = [];

async function main() {
  if (Deno.args.length >= 2) {
    const subcommand = Deno.args[0];
    if (subcommand !== "start") {
      console.log(`Run as 'elm-server start Server.elm [arguments]'`);
      console.log(subcommand);
      exit(1);
    }
    const sourceFileName = Deno.args[1];
    const commandLineArgs = Deno.args.slice(2);
    const absolutePath = path.resolve(sourceFileName);
    const extension = path.extname(absolutePath);
    if (extension === ".js") {
      runCompiledJs(absolutePath, commandLineArgs);
    } else if (extension === ".elm") {
      const tempDirectory = createTemporaryDirectory();
      const tempFileName = path.resolve(tempDirectory, "main.js");
      const elmFileDirectory = path.dirname(absolutePath);
      const elmProcess = Deno.run({
        cmd: [
          "elm",
          "make",
          "--optimize",
          "--output=" + tempFileName,
          absolutePath,
        ],
        stdout: "piped",
        cwd: elmFileDirectory,
      });
      const elmResult = await elmProcess.status();
      if (elmResult.success) {
        runCompiledJs(tempFileName, commandLineArgs);
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
  } else {
    console.log(`Run as 'elm-server start Server.elm [arguments]'`);
    exit(1);
  }
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

function runCompiledJs(jsFileName, commandLineArgs) {
  // Read compiled JS from file
  const jsData = Deno.readFileSync(jsFileName);
  const jsText = new TextDecoder("utf-8").decode(jsData);

  // Add our mock XMLHttpRequest class into the global namespace
  // so that Elm code will use it
  // globalThis["XMLHttpRequest"] = XMLHttpRequest;

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
      flags["platform"] = { type: "posix", name: Deno.build.os };
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
  // Start Elm program
  // console.log("Debug", flags.environment);
  const elmServer = module.init({ flags: flags });

  function respond(response) {
    elmServer.ports.respond.send(response);
  }

  elmServer.ports.command.subscribe(async function (command) {
    console.log(command.msg);
    switch (command.msg) {
      case "SERVE":
        {
          const { databaseConnection, port } = command.args;
          const server = denoHttp.serve({ port });
          let databasePool;

          if (databaseConnection != null) {
            const POOL_CONNECTIONS = 20;
            const {
              hostname,
              port,
              user,
              password,
              database,
            } = databaseConnection;
            databasePool = new Pool(
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

          respond({ msg: "SERVED", args: { server, databasePool } });

          for await (const req of server) {
            respond({ msg: "REQUEST", args: req });
          }
        }
        break;
      case "RESPOND":
        {
          command.args.req.respond(command.args.options);
        }
        break;
      case "CLOSE":
        {
          command.args.server.close();
          respond({ msg: "CLOSED ", args: null });
        }
        break;
      case "PRINT":
        console.log(command.args);
        break;
      case "DATABASE_QUERY":
        {
          console.log("query args", command.args.query);
          const client = await command.args.actual.databasePool.connect();
          const result = await client.query(command.args.query.text);
          // const result = await client.query({
          //   text: command.args.query.text,
          //   args: command.args.query.args,
          //   // text: "SELECT * FROM people WHERE age > $1 AND age < $2;",
          //   // args: [10, 20],
          // });
          client.release();
          respond({
            msg: "CONTINUE",
            args: { id: command.args.continuationKey, result },
          });
        }
        break;
      default:
        console.error(
          `Error: Unknown server command: "${command.msg}"`,
          command.args
        );
    }
  });
}

// class XMLHttpRequest {
//   constructor() {
//     this.status = 200;
//     this.statusText = "200 OK";
//     this.responseUrl = "/runner";
//   }

//   getAllResponseHeaders() {
//     return "";
//   }

//   setRequestHeader(name, value) {
//     return;
//   }

//   open(method, url, performAsync) {
//     return;
//   }

//   addEventListener(name, callback) {
//     if (name == "load") {
//       this._callback = callback;
//     }
//   }

//   async send(request) {
//     let xhr = this;
//     function handleResponse(response) {
//       xhr.response = JSON.stringify(response);
//       xhr._callback();
//     }
//     request = JSON.parse(request);
//     switch (request.name) {
//       case "checkVersion":
//         const requiredMajorProtocolVersion = request.value[0];
//         const requiredMinorProtocolVersion = request.value[1];
//         const describeCurrentProtocolVersion =
//           ` (current elm-run protocol version: ${majorProtocolVersion}.${minorProtocolVersion})`;
//         if (requiredMajorProtocolVersion !== majorProtocolVersion) {
//           console.log(
//             "Version mismatch: script requires elm-run major protocol version " +
//             requiredMajorProtocolVersion +
//             describeCurrentProtocolVersion,
//           );
//           if (requiredMajorProtocolVersion > majorProtocolVersion) {
//             console.log("Please update to a newer version of elm-run");
//           } else {
//             console.log(
//               "Please update script to use a newer version of the ianmackenzie/elm-script package",
//             );
//           }
//           exit(1);
//         } else if (requiredMinorProtocolVersion > minorProtocolVersion) {
//           const requiredProtocolVersionString = requiredMajorProtocolVersion +
//             "." + requiredMinorProtocolVersion;
//           console.log(
//             "Version mismatch: script requires elm-run protocol version at least " +
//             requiredProtocolVersionString +
//             describeCurrentProtocolVersion,
//           );
//           console.log("Please update to a newer version of elm-run");
//           exit(1);
//         } else {
//           handleResponse(null);
//         }
//         break;
//       case "writeStdout":
//         try {
//           const data = new TextEncoder().encode(request.value);
//           Deno.stdout.writeSync(data);
//           handleResponse(null);
//         } catch (error) {
//           console.log("Error printing to stdout");
//           exit(1);
//         }
//         break;
//       case "exit":
//         exit(request.value);
//       case "abort":
//         const data = new TextEncoder().encode(request.value);
//         Deno.stdout.writeSync(data);
//         exit(1);
//       case "readFile":
//         try {
//           const filePath = resolvePath(request.value);
//           const data = Deno.readFileSync(filePath);
//           const contents = new TextDecoder("utf-8").decode(data);
//           handleResponse(contents);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "writeFile":
//         try {
//           const filePath = resolvePath(request.value.path);
//           const contents = new TextEncoder().encode(request.value.contents);
//           Deno.writeFileSync(filePath, contents);
//           handleResponse(null);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "listFiles":
//         listEntities(request, handleResponse, (fileInfo) => fileInfo.isFile);
//         break;
//       case "listSubdirectories":
//         listEntities(
//           request,
//           handleResponse,
//           (fileInfo) => fileInfo.isDirectory,
//         );
//         break;
//       case "execute":
//         try {
//           const process = Deno.run({
//             cmd: [request.value.command, ...request.value.arguments],
//             cwd: resolvePath(request.value.workingDirectory),
//             stdout: "piped",
//             stderr: "piped"
//           });
//           const outputData = await process.output();
//           const errorOutputData = await process.stderrOutput();
//           const result = await process.status();
//           if (result.success) {
//             const output = new TextDecoder("utf-8").decode(outputData);
//             handleResponse(output);
//           } else {
//             if (result.code !== null) {
//               handleResponse({ error: "exited", code: result.code });
//             } else if (result.signal !== null) {
//               handleResponse({ error: "terminated" });
//             } else {
//               const errorOutput = new TextDecoder("utf-8").decode(errorOutputData);
//               handleResponse({ error: "failed", message: errorOutput });
//             }
//           }
//         } catch (error) {
//           if (error instanceof Deno.errors.NotFound) {
//             handleResponse({ error: "notfound" });
//           } else {
//             console.log(error);
//             exit(1);
//           }
//         }
//         break;
//       case "copyFile":
//         try {
//           const sourcePath = resolvePath(request.value.sourcePath);
//           const destinationPath = resolvePath(request.value.destinationPath);
//           Deno.copyFileSync(sourcePath, destinationPath);
//           handleResponse(null);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "moveFile":
//         try {
//           const sourcePath = resolvePath(request.value.sourcePath);
//           const destinationPath = resolvePath(request.value.destinationPath);
//           Deno.renameSync(sourcePath, destinationPath);
//           handleResponse(null);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "deleteFile":
//         try {
//           const filePath = resolvePath(request.value);
//           Deno.removeSync(filePath);
//           handleResponse(null);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "stat":
//         try {
//           const entityPath = resolvePath(request.value);
//           const fileInfo = Deno.statSync(entityPath);
//           if (fileInfo.isFile) {
//             handleResponse("file");
//           } else if (fileInfo.isDirectory) {
//             handleResponse("directory");
//           } else {
//             handleResponse("other");
//           }
//         } catch (error) {
//           if (error instanceof Deno.errors.NotFound) {
//             handleResponse("nonexistent");
//           } else {
//             handleResponse({ message: error.message });
//           }
//         }
//         break;
//       case "createDirectory":
//         try {
//           const directoryPath = resolvePath(request.value.path);
//           Deno.mkdirSync(directoryPath, { recursive: request.value.recursive });
//           handleResponse(null);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "removeDirectory":
//         try {
//           const directoryPath = resolvePath(request.value.path);
//           Deno.removeSync(directoryPath, {
//             recursive: request.value.recursive,
//           });
//           handleResponse(null);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "createTemporaryDirectory":
//         try {
//           const directoryPath = createTemporaryDirectory();
//           handleResponse(directoryPath);
//         } catch (error) {
//           handleResponse({ message: error.message });
//         }
//         break;
//       case "http":
//         try {
//           let promise = fetch(request.value.url, request.value.options);
//           if (request.value.timeout != null) {
//             promise = timeout(request.value.timeout, promise);
//           }
//           const httpResponse = await promise;
//           const responseBody = await httpResponse.text();
//           handleResponse({
//             status: httpResponse.status,
//             body: responseBody,
//           });
//         } catch (error) {
//           let errorType = null;
//           if (error.message == "timeout") {
//             errorType = "Timeout";
//           } else {
//             errorType = "NetworkError";
//           }
//           handleResponse({ error: errorType });
//         }
//         break;
//       default:
//         console.log(`Internal error - unexpected request ${request}`);
//         console.log(
//           "Try updating to newer versions of elm-run and the ianmackenzie/elm-script package",
//         );
//         exit(1);
//     };
//   }
// };

main();
