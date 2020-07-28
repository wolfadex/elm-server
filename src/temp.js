import * as denoHttp from "https://deno.land/std/http/server.ts";

const server = denoHttp.serve({ port: 1234 });
console.log("carl");
server.close();
