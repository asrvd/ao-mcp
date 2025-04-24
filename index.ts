#!/usr/bin/env node
import { createSigner, message, spawn, result } from "@permaweb/aoconnect";
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
          text: `Process spawned with tags: ${tags.join(
            ", "
          )} and processId: ${processId}`,
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

server.tool(
  "transaction",
  { transactionId: z.string() },
  async ({ transactionId }) => {
    try {
      const metadataResponse = await fetch(
        `https://arweave.net/tx/${transactionId}`
      );
      const metadata = await metadataResponse.json();

      const dataResponse = await fetch(
        `https://arweave.net/raw/${transactionId}`
      );
      const data = await dataResponse.text();

      const transactionInfo = {
        id: metadata.id,
        owner: metadata.owner,
        recipient: metadata.target,
        quantity: metadata.quantity,
        fee: metadata.reward,
        data_size: metadata.data_size,
        data: data.substring(0, 1000), // Limit data preview to first 1000 chars
        tags: metadata.tags || [],
      };

      return {
        content: [
          {
            type: "text",
            text: `Transaction Information:\n${JSON.stringify(
              transactionInfo,
              null,
              2
            )}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `Error fetching transaction: ${error}`,
          },
        ],
      };
    }
  }
);

async function runLuaCode(code: string, processId: string) {
  const messageId = await message({
    process: processId,
    signer,
    data: code,
    tags: [{ name: "Action", value: "Eval" }],
  });

  const outputResult = await result({
    message: messageId,
    process: processId,
  });

  return JSON.stringify(outputResult.Output.data);
}

async function fetchBlueprintCode(url: string) {
  const response = await fetch(url);
  const code = await response.text();
  return code;
}

async function listHandlers(processId: string) {
  const messageId = await message({
    process: processId,
    signer,
    data: `
      local handlers = Handlers.list
      local result = {}
      for i, handler in ipairs(handlers) do
        table.insert(result, {
          name = handler.name,
          type = type(handler.pattern),
        })
      end
      return result
    `,
    tags: [{ name: "Action", value: "Eval" }],
  });
  const outputResult = await result({
    message: messageId,
    process: processId,
  });
  return outputResult.Output.data;
}

server.tool(
  "run-lua-code",
  { code: z.string(), processId: z.string() },
  async ({ code, processId }) => {
    const result = await runLuaCode(code, processId);
    return {
      content: [
        {
          type: "text",
          text:
            "Code executed successfully" +
            "\n" +
            `output: ${JSON.stringify(result as string, null, 2)
              .replace(/\\u001b\[\d+m/g, "") // Remove ANSI color codes
              .replace(/\\n/g, "\n")}`,
        },
      ],
    };
  }
);

server.tool(
  "load-blueprint",
  { url: z.string(), processId: z.string() },
  async ({ url, processId }) => {
    const code = await fetchBlueprintCode(url);
    const result = await runLuaCode(code, processId);
    return {
      content: [{ type: "text", text: result }],
    };
  }
);

server.tool(
  "list-available-handlers",
  { processId: z.string() },
  async ({ processId }) => {
    const handlers = await listHandlers(processId);
    return {
      content: [
        {
          type: "text",
          text:
            "Available Handlers:\n" +
            JSON.stringify(handlers, null, 2)
              .replace(/\\u001b\[\d+m/g, "") // Remove ANSI color codes
              .replace(/\\n/g, "\n"), // Fix newlines
        },
      ],
    };
  }
);
const transport = new StdioServerTransport();
await server.connect(transport);
