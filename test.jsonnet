// config.jsonnet
local env = "production";

local defaults = {
  replicas: 1,
  port: 8080,
  logLevel: "info",
};

local appConfig(name, overrides={}) = defaults + overrides + {
  name: name,
  env: env,
  labels: {
    app: name,
    environment: env,
  },
};

{
  webServer: appConfig("web-server", { replicas: 3, port: 443 }),
  workerService: appConfig("worker", { replicas: 5, logLevel: "debug" }),
  cache: appConfig("redis", { port: 6379 }),
}
