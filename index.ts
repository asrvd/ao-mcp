#!/usr/bin/env node
import { createSigner, message, spawn } from "@permaweb/aoconnect";
import fs from "node:fs";
import {
  McpServer,
  ResourceTemplate,
} from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// Create an MCP server
const server = new McpServer({
  name: "ao-mcp",
  version: "1.0.0",
});

const wallet = JSON.parse(
  fs.readFileSync("/Users/asrvd/dev/web3/ao-mcp/keyfile.json", "utf8")
);
const signer = createSigner(wallet);

// Add an addition tool
server.tool("add", { a: z.number(), b: z.number() }, async ({ a, b }) => ({
  content: [{ type: "text", text: String(a + b) }],
}));

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
    const processId = await spawn({
      module: "JArYBF-D8q2OmZ4Mok00sD2Y_6SYEQ7Hjx-6VZ_jl3g",
      signer,
      scheduler: "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA",
      tags,
    });
    return {
      content: [
        {
          type: "text",
          text: `Process spawned with tags: ${tags.join(", ")}`,
          processId: processId,
        },
      ],
    };
  }
);

server.tool(
  "send-message",
  { processId: z.string(), data: z.string() },
  async ({ processId, data }) => {
    const status = await message({
      process: processId,
      signer,
      data,
    });
    return {
      content: [{ type: "text", text: status }],
    };
  }
);
const transport = new StdioServerTransport();
await server.connect(transport);
