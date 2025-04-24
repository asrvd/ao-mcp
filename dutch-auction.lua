-- Dutch Auction Process for AO tokens
-- This process implements a simple reverse dutch auction for AO tokens

-- State to track auctions
local Auctions = {}

-- Initialize state
local State = {
    token = nil,    -- Token process ID
    seller = nil,   -- Address of seller
    startPrice = nil, -- Starting price in credits
    decayRate = nil, -- Price decay per block
    startBlock = nil, -- Block when auction started
    active = false  -- Whether auction is currently active
}

-- Initialize the process
function Init()
    print("Dutch Auction Process Initialized")
    Handlers.add("Deposit", HandleDeposit)
    Handlers.add("Buy", HandleBuy)
    Handlers.add("Info", HandleInfo)
    Handlers.add("Balance", HandleBalance)
    Handlers.add("StartAuction", StartAuction)
    Handlers.add("GetPrice", GetPrice)
    Handlers.add("Purchase", Purchase)
    Handlers.add("GetInfo", GetInfo)

    -- Track the process balance of tokens
    Memory.set("tokenBalances", {})
end

-- Handle token deposits to start an auction
function HandleDeposit(msg)
    -- Check required parameters
    local token = msg.Tags.Token
    local amount = tonumber(msg.Tags.Amount)
    local startPrice = tonumber(msg.Tags.StartPrice)
    local decayRate = tonumber(msg.Tags.DecayRate) -- Units per second

    if not token or not amount or not startPrice or not decayRate then
        return msg:reply({
            Target = msg.From,
            Data = "Missing required parameters: Token, Amount, StartPrice, DecayRate"
        })
    end

    -- Create auction ID
    local auctionId = ao.id .. "-" .. #Auctions + 1

    -- Create auction
    local auction = {
        id = auctionId,
        seller = msg.From,
        token = token,
        amount = amount,
        startPrice = startPrice,
        decayRate = decayRate,
        startTime = os.time(),
        active = true
    }

    -- Transfer tokens to this process
    ao.send({
        Target = token,
        Action = "Transfer",
        Quantity = tostring(amount),
        Recipient = ao.id,
        Owner = msg.From
    })

    -- Save auction
    table.insert(Auctions, auction)

    -- Update token balance for this process
    local tokenBalances = Memory.get("tokenBalances") or {}
    tokenBalances[token] = (tokenBalances[token] or 0) + amount
    Memory.set("tokenBalances", tokenBalances)

    return msg:reply({
        Target = msg.From,
        Data = "Auction created with ID: " .. auctionId
    })
end

-- Calculate current price based on time elapsed
function GetCurrentPrice(auction)
    local timeElapsed = os.time() - auction.startTime
    local priceDrop = timeElapsed * auction.decayRate
    local currentPrice = auction.startPrice - priceDrop

    -- Never go below zero
    return math.max(0, currentPrice)
end

-- Handle buying from an auction
function HandleBuy(msg)
    local auctionId = msg.Tags.AuctionId

    if not auctionId then
        return msg:reply({
            Target = msg.From,
            Data = "Missing AuctionId parameter"
        })
    end

    -- Find auction
    local auction = nil
    for _, a in ipairs(Auctions) do
        if a.id == auctionId then
            auction = a
            break
        end
    end

    if not auction then
        return msg:reply({
            Target = msg.From,
            Data = "Auction not found with ID: " .. auctionId
        })
    end

    if not auction.active then
        return msg:reply({
            Target = msg.From,
            Data = "Auction already completed"
        })
    end

    -- Calculate current price
    local currentPrice = GetCurrentPrice(auction)

    -- Transfer payment to seller
    ao.send({
        Target = auction.token,
        Action = "Transfer",
        Quantity = tostring(currentPrice),
        Recipient = auction.seller,
        Owner = msg.From
    })

    -- Transfer token to buyer
    ao.send({
        Target = auction.token,
        Action = "Transfer",
        Quantity = tostring(auction.amount),
        Recipient = msg.From,
        Owner = ao.id
    })

    -- Mark auction as completed
    auction.active = false
    auction.buyer = msg.From
    auction.finalPrice = currentPrice

    -- Update token balance for this process
    local tokenBalances = Memory.get("tokenBalances") or {}
    tokenBalances[auction.token] = (tokenBalances[auction.token] or 0) - auction.amount
    Memory.set("tokenBalances", tokenBalances)

    return msg:reply({
        Target = msg.From,
        Data = "Successfully purchased from auction " .. auctionId .. " for " .. currentPrice
    })
end

-- Get info about an auction
function HandleInfo(msg)
    local auctionId = msg.Tags.AuctionId

    if not auctionId then
        -- List all active auctions
        local activeAuctions = {}
        for _, auction in ipairs(Auctions) do
            if auction.active then
                local info = {
                    id = auction.id,
                    token = auction.token,
                    amount = auction.amount,
                    currentPrice = GetCurrentPrice(auction)
                }
                table.insert(activeAuctions, info)
            end
        end

        return msg:reply({
            Target = msg.From,
            Data = "Active auctions: " .. ao.json.encode(activeAuctions)
        })
    else
        -- Get specific auction info
        for _, auction in ipairs(Auctions) do
            if auction.id == auctionId then
                local info = {
                    id = auction.id,
                    seller = auction.seller,
                    token = auction.token,
                    amount = auction.amount,
                    startPrice = auction.startPrice,
                    decayRate = auction.decayRate,
                    startTime = auction.startTime,
                    active = auction.active,
                    currentPrice = auction.active and GetCurrentPrice(auction) or nil,
                    buyer = auction.buyer,
                    finalPrice = auction.finalPrice
                }

                return msg:reply({
                    Target = msg.From,
                    Data = ao.json.encode(info)
                })
            end
        end

        return msg:reply({
            Target = msg.From,
            Data = "Auction not found with ID: " .. auctionId
        })
    end
end

-- Get token balance of this process
function HandleBalance(msg)
    local token = msg.Tags.Token

    if not token then
        return msg:reply({
            Target = msg.From,
            Data = "Missing Token parameter"
        })
    end

    local tokenBalances = Memory.get("tokenBalances") or {}
    local balance = tokenBalances[token] or 0

    return msg:reply({
        Target = msg.From,
        Data = "Balance of token " .. token .. ": " .. balance
    })
end

-- Helper to calculate current price
local function getCurrentPrice()
    if not State.active then return nil end

    local currentBlock = ao.block
    local blocksPassed = currentBlock - State.startBlock
    local decayAmount = blocksPassed * State.decayRate
    local currentPrice = State.startPrice - decayAmount

    -- Don't allow price to go below 0
    return math.max(currentPrice, 0)
end

-- Handler for starting an auction
Handlers.add("StartAuction", function(msg)
    -- Ensure auction isn't already active
    if State.active then
        return ao.send({ Target = msg.From, Data = "Error: Auction already active" })
    end

    -- Validate required tags
    if not msg.Tags.Token or not msg.Tags.StartPrice or not msg.Tags.DecayRate then
        return ao.send({
            Target = msg.From,
            Data = "Error: Missing required tags. Need Token, StartPrice, and DecayRate"
        })
    end

    -- Parse and validate parameters
    local startPrice = tonumber(msg.Tags.StartPrice)
    local decayRate = tonumber(msg.Tags.DecayRate)

    if not startPrice or not decayRate or startPrice <= 0 or decayRate <= 0 then
        return ao.send({
            Target = msg.From,
            Data = "Error: Invalid price or decay rate. Must be positive numbers"
        })
    end

    -- Initialize auction state
    State.token = msg.Tags.Token
    State.seller = msg.From
    State.startPrice = startPrice
    State.decayRate = decayRate
    State.startBlock = ao.block
    State.active = true

    -- Request token transfer from seller
    ao.send({
        Target = State.token,
        Action = "Transfer",
        Quantity = "1",
        Target = ao.id, -- Transfer to this process
        From = msg.From
    })

    return ao.send({
        Target = msg.From,
        Data = "Auction started successfully"
    })
end)

-- Handler for checking current price
Handlers.add("GetPrice", function(msg)
    if not State.active then
        return ao.send({ Target = msg.From, Data = "No active auction" })
    end

    local currentPrice = getCurrentPrice()
    return ao.send({
        Target = msg.From,
        Data = "Current price: " .. tostring(currentPrice)
    })
end)

-- Handler for purchasing the token
Handlers.add("Purchase", function(msg)
    if not State.active then
        return ao.send({ Target = msg.From, Data = "Error: No active auction" })
    end

    local currentPrice = getCurrentPrice()

    -- Verify payment amount
    if not msg.Value or tonumber(msg.Value) < currentPrice then
        return ao.send({
            Target = msg.From,
            Data = "Error: Insufficient payment. Current price is " .. tostring(currentPrice)
        })
    end

    -- Transfer token to buyer
    ao.send({
        Target = State.token,
        Action = "Transfer",
        Quantity = "1",
        Target = msg.From,
        From = ao.id
    })

    -- Transfer payment to seller
    ao.send({
        Target = State.seller,
        Value = tostring(currentPrice)
    })

    -- Reset auction state
    State.active = false

    return ao.send({
        Target = msg.From,
        Data = "Purchase successful at price " .. tostring(currentPrice)
    })
end)

-- Handler for getting auction info
Handlers.add("GetInfo", function(msg)
    if not State.active then
        return ao.send({ Target = msg.From, Data = "No active auction" })
    end

    local info = {
        seller = State.seller,
        token = State.token,
        startPrice = State.startPrice,
        decayRate = State.decayRate,
        startBlock = State.startBlock,
        currentPrice = getCurrentPrice()
    }

    return ao.send({
        Target = msg.From,
        Data = json.encode(info)
    })
end)

-- Initialize the process
Init()
