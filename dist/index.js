#!/usr/bin/env node

// index.ts
import { createSigner, spawn } from "@permaweb/aoconnect";
import fs from "node:fs";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
var server = new McpServer({
  name: "ao-mcp",
  version: "1.0.0",
});
var wallet = JSON.parse(
  fs.readFileSync("/Users/asrvd/dev/web3/ao-mcp/keyfile.json", "utf8")
);
var signer = createSigner(wallet);
server.tool("add", { a: z.number(), b: z.number() }, async ({ a, b }) => ({
  content: [{ type: "text", text: String(a + b) }],
}));
server.tool(
  "calculate-bmi",
  {
    weightKg: z.number(),
    heightM: z.number(),
  },
  async ({ weightKg, heightM }) => ({
    content: [
      {
        type: "text",
        text: String(weightKg / (heightM * heightM)),
      },
    ],
  })
);
server.tool(
  "spawn",
  {
    tags: z.array(
      z.object({
        name: z.string(),
        value: z.string(),
      })
    ),
  },
  async ({ tags }) => {
    try {
      const processId = await spawn({
        module: "JArYBF-D8q2OmZ4Mok00sD2Y_6SYEQ7Hjx-6VZ_jl3g",
        signer,
        scheduler: "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA",
        tags,
      });
      console.log(processId);
      return {
        content: [
          {
            type: "text",
            text: `Process spawned with tags: ${tags.join(", ")}, processId: ${processId}`,
          },
        ],
      };
    } catch (error) {
      console.error("error spawning process", error);
      return {
        content: [{ type: "text", text: "Error spawning process" }],
      };
    }
  }
);
var transport = new StdioServerTransport();
await server.connect(transport);
