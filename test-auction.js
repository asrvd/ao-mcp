// Test script for Dutch Auction
// This script demonstrates how to use the Dutch auction process

// Step 1: Spawn a process
async function spawnAuctionProcess() {
  const processId = await mcp_ao_mcp_spawn({
    tags: [
      { name: "Action", value: "Spawn" },
      { name: "Module", value: "JArYBF-D8q2OmZ4Mok00sD2Y_6SYEQ7Hjx-6VZ_jl3g" }, // Default AO module
    ],
  });
  console.log(`Process spawned with ID: ${processId}`);
  return processId;
}

// Step 2: Load the Dutch auction code into the process
async function loadAuctionCode(processId) {
  // Read the dutch-auction.lua file content and load it
  const fs = require("fs");
  const auctionCode = fs.readFileSync("./dutch-auction.lua", "utf8");

  const result = await mcp_ao_mcp_run_lua_code({
    processId: processId,
    code: auctionCode,
  });
  console.log("Auction code loaded successfully");
  return result;
}

// Step 3: Create an auction
async function createAuction(
  processId,
  tokenId,
  amount,
  startPrice,
  decayRate
) {
  const result = await mcp_ao_mcp_send_message({
    processId: processId,
    data: "Starting a new auction",
    tags: [
      { name: "Action", value: "Deposit" },
      { name: "Token", value: tokenId },
      { name: "Amount", value: amount.toString() },
      { name: "StartPrice", value: startPrice.toString() },
      { name: "DecayRate", value: decayRate.toString() },
    ],
  });
  console.log(`Auction created: ${result}`);
  return result;
}

// Step 4: List all active auctions
async function listAuctions(processId) {
  const result = await mcp_ao_mcp_send_message({
    processId: processId,
    data: "Show me active auctions",
    tags: [{ name: "Action", value: "Info" }],
  });
  console.log(`Active auctions: ${result}`);
  return result;
}

// Step 5: Get details of a specific auction
async function getAuctionDetails(processId, auctionId) {
  const result = await mcp_ao_mcp_send_message({
    processId: processId,
    data: "Show auction details",
    tags: [
      { name: "Action", value: "Info" },
      { name: "AuctionId", value: auctionId },
    ],
  });
  console.log(`Auction details: ${result}`);
  return result;
}

// Step 6: Buy tokens from an auction
async function buyFromAuction(processId, auctionId) {
  const result = await mcp_ao_mcp_send_message({
    processId: processId,
    data: "I want to buy this token",
    tags: [
      { name: "Action", value: "Buy" },
      { name: "AuctionId", value: auctionId },
    ],
  });
  console.log(`Purchase result: ${result}`);
  return result;
}

// Step 7: Check token balance of the process
async function checkTokenBalance(processId, tokenId) {
  const result = await mcp_ao_mcp_send_message({
    processId: processId,
    data: "Check token balance",
    tags: [
      { name: "Action", value: "Balance" },
      { name: "Token", value: tokenId },
    ],
  });
  console.log(`Token balance: ${result}`);
  return result;
}

// Main function to run the test
async function runTest() {
  // Replace these with your actual values
  const tokenProcessId = "YOUR_TOKEN_PROCESS_ID";

  try {
    // Step 1: Spawn a process
    const processId = await spawnAuctionProcess();

    // Step 2: Load the auction code
    await loadAuctionCode(processId);

    // Step 3: Create an auction
    await createAuction(processId, tokenProcessId, 10, 100, 0.5);

    // Step 4: List all active auctions
    const auctions = await listAuctions(processId);

    // Parse the auction list response to get the first auction ID
    // In a real application, you would parse the JSON response properly
    const auctionId = "AUCTION_ID_FROM_RESPONSE";

    // Step 5: Get details of the specific auction
    await getAuctionDetails(processId, auctionId);

    // Wait for a few seconds to see the price decrease
    console.log("Waiting for 10 seconds to see price decrease...");
    await new Promise((resolve) => setTimeout(resolve, 10000));

    // Check the updated price
    await getAuctionDetails(processId, auctionId);

    // Step 6: Buy from the auction
    await buyFromAuction(processId, auctionId);

    // Step 7: Check the process token balance after purchase
    await checkTokenBalance(processId, tokenProcessId);
  } catch (error) {
    console.error("Error during test:", error);
  }
}

// Uncomment to run the test
// runTest();
