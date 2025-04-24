-- Initialize token state
local Balances = {}
local TotalSupply = 1000

-- Initialize the token with balance to creator
function Init()
    Balances[ao.id] = TotalSupply
end

-- Handle balance queries
Handlers.add("Balance", function(msg)
    local target = msg.Tags.Target or msg.From
    return ao.send({
        Target = msg.From,
        Data = tostring(Balances[target] or 0)
    })
end)

-- Handle transfers
Handlers.add("Transfer", function(msg)
    local from = msg.From
    local to = msg.Tags.Target
    local qty = tonumber(msg.Tags.Quantity)

    if not to or not qty then
        return ao.send({
            Target = from,
            Data = "Error: Missing target or quantity"
        })
    end

    -- Check balance
    if not Balances[from] or Balances[from] < qty then
        return ao.send({
            Target = from,
            Data = "Error: Insufficient balance"
        })
    end

    -- Update balances
    Balances[from] = Balances[from] - qty
    Balances[to] = (Balances[to] or 0) + qty

    return ao.send({
        Target = from,
        Data = "Transfer successful"
    })
end)

-- Initialize
Init()
