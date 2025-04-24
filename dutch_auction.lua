-- Reverse Dutch Auction Process
-- Stores active auctions and their details
local Auctions = {}

-- Initialize handlers table
Handlers.add("Init", function(msg)
    ao.id = msg.From
    -- Initialize any necessary state
    print("Dutch auction process initialized")
end)

-- Handler for creating a new auction
Handlers.add("CreateAuction", function(msg)
    -- Validate required tags
    if not msg.Tags.TokenId or not msg.Tags.StartPrice or not msg.Tags.DecayRate then
        return msg.reply({
            Target = msg.From,
            Data = "Error: Missing required parameters. Need TokenId, StartPrice, and DecayRate"
        })
    end

    local tokenId = msg.Tags.TokenId
    local startPrice = tonumber(msg.Tags.StartPrice)
    local decayRate = tonumber(msg.Tags.DecayRate)

    if not startPrice or not decayRate then
        return msg.reply({
            Target = msg.From,
            Data = "Error: StartPrice and DecayRate must be numbers"
        })
    end

    -- Create new auction
    local auctionId = ao.id .. "-" .. #Handlers.list + 1
    Auctions[auctionId] = {
        seller = msg.From,
        tokenId = tokenId,
        startPrice = startPrice,
        decayRate = decayRate,
        startTime = os.time(),
        active = true
    }

    -- Request token transfer from seller
    ao.send({
        Target = tokenId,
        Action = "Transfer",
        Quantity = "1",
        Recipient = ao.id,
        Tags = {
            ["Action"] = "Transfer",
            ["Recipient"] = ao.id
        }
    })

    msg.reply({
        Target = msg.From,
        Data = "Auction created with ID: " .. auctionId
    })
end)

-- Handler for getting current price of an auction
Handlers.add("GetPrice", function(msg)
    if not msg.Tags.AuctionId then
        return msg.reply({
            Target = msg.From,
            Data = "Error: Missing AuctionId"
        })
    end

    local auction = Auctions[msg.Tags.AuctionId]
    if not auction then
        return msg.reply({
            Target = msg.From,
            Data = "Error: Auction not found"
        })
    end

    if not auction.active then
        return msg.reply({
            Target = msg.From,
            Data = "Error: Auction has ended"
        })
    end

    local timeElapsed = os.time() - auction.startTime
    local currentPrice = auction.startPrice - (timeElapsed * auction.decayRate)
    currentPrice = math.max(currentPrice, 0) -- Don't go below 0

    msg.reply({
        Target = msg.From,
        Data = tostring(currentPrice)
    })
end)

-- Handler for purchasing the token
Handlers.add("Purchase", function(msg)
    if not msg.Tags.AuctionId then
        return msg.reply({
            Target = msg.From,
            Data = "Error: Missing AuctionId"
        })
    end

    local auction = Auctions[msg.Tags.AuctionId]
    if not auction or not auction.active then
        return msg.reply({
            Target = msg.From,
            Data = "Error: Auction not found or has ended"
        })
    end

    local timeElapsed = os.time() - auction.startTime
    local currentPrice = auction.startPrice - (timeElapsed * auction.decayRate)
    currentPrice = math.max(currentPrice, 0)

    -- Transfer token to buyer
    ao.send({
        Target = auction.tokenId,
        Action = "Transfer",
        Quantity = "1",
        Recipient = msg.From,
        Tags = {
            ["Action"] = "Transfer",
            ["Recipient"] = msg.From
        }
    })

    -- Mark auction as ended
    auction.active = false
    auction.winner = msg.From
    auction.finalPrice = currentPrice

    msg.reply({
        Target = msg.From,
        Data = "Successfully purchased token for " .. tostring(currentPrice)
    })
end)

-- Handler for listing all active auctions
Handlers.add("ListAuctions", function(msg)
    local activeAuctions = {}
    for id, auction in pairs(Auctions) do
        if auction.active then
            local timeElapsed = os.time() - auction.startTime
            local currentPrice = auction.startPrice - (timeElapsed * auction.decayRate)
            currentPrice = math.max(currentPrice, 0)

            activeAuctions[id] = {
                seller = auction.seller,
                tokenId = auction.tokenId,
                currentPrice = currentPrice
            }
        end
    end

    msg.reply({
        Target = msg.From,
        Data = json.encode(activeAuctions)
    })
end)
