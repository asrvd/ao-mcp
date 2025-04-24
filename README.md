# AO Dutch Auction Process

A simple reverse Dutch auction for AO tokens, where the price decreases over time according to a set decay rate.

## How It Works

1. A seller deposits a token into the auction, setting:
   - Starting price
   - Decay rate (price reduction per second)

2. The auction price automatically decreases over time according to the formula:
   - Current Price = Starting Price - (Time Elapsed × Decay Rate)

3. Any buyer can purchase the token at the current price at any time.

## Usage

### Spawn the Process

First, spawn the process using the provided MCP tools:

```js
// Replace MODULE_ID with the actual module ID
const processId = await mcp_ao-mcp_spawn({
  tags: [
    { name: "Action", value: "Spawn" },
    { name: "Module", value: "MODULE_ID" }
  ]
});
```

### Load the Auction Blueprint

Load the auction code into the process:

```js
await mcp_ao-mcp_run-lua-code({
  processId: "YOUR_PROCESS_ID",
  code: // Contents of dutch-auction.lua
});
```

### Creating an Auction

To create an auction, send a message with the Deposit action:

```js
await mcp_ao-mcp_send-message({
  processId: "YOUR_PROCESS_ID",
  data: "Starting a new auction",
  tags: [
    { name: "Action", value: "Deposit" },
    { name: "Token", value: "TOKEN_PROCESS_ID" },
    { name: "Amount", value: "1" },
    { name: "StartPrice", value: "100" },
    { name: "DecayRate", value: "0.1" } // Price decreases by 0.1 per second
  ]
});
```

### Viewing Available Auctions

To view all active auctions:

```js
await mcp_ao-mcp_send-message({
  processId: "YOUR_PROCESS_ID",
  data: "Show me active auctions",
  tags: [
    { name: "Action", value: "Info" }
  ]
});
```

### View a Specific Auction

To get details of a specific auction:

```js
await mcp_ao-mcp_send-message({
  processId: "YOUR_PROCESS_ID",
  data: "Show auction details",
  tags: [
    { name: "Action", value: "Info" },
    { name: "AuctionId", value: "AUCTION_ID" }
  ]
});
```

### Buying from an Auction

To purchase a token at the current price:

```js
await mcp_ao-mcp_send-message({
  processId: "YOUR_PROCESS_ID",
  data: "I want to buy this token",
  tags: [
    { name: "Action", value: "Buy" },
    { name: "AuctionId", value: "AUCTION_ID" }
  ]
});
```

### Checking Token Balance

To check the process's token balance:

```js
await mcp_ao-mcp_send-message({
  processId: "YOUR_PROCESS_ID",
  data: "Check token balance",
  tags: [
    { name: "Action", value: "Balance" },
    { name: "Token", value: "TOKEN_PROCESS_ID" }
  ]
});
```

## Important Notes

1. Before creating an auction, ensure the seller has sufficient token balance
2. The buyer must have enough tokens to cover the current price
3. The process interacts with AO token processes that follow the token standard
4. All prices are denominated in the same token type being auctioned

## Example Use Case

1. Alice wants to sell 10 XYZ tokens starting at 100 tokens with a decay rate of 0.5 tokens per second
2. She creates an auction using the Deposit action
3. Bob checks active auctions with the Info action
4. After 20 seconds, the price has dropped to 90 tokens (100 - 20 × 0.5)
5. Bob decides to buy the tokens at the current price using the Buy action
6. The auction automatically transfers 10 XYZ tokens to Bob and 90 XYZ tokens to Alice 