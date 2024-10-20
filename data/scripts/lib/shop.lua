-- Shop Restock Button logic with new Cooldown logic
local edr_buildBuyGui, edr_CreateNamespace -- extended functions
local edr_restockButton                    -- UI
local edr_specialOfferSeed = 0             -- restock the special offer
local restockCooldown = 15 * 60            -- 15 minutes in seconds
local lastRestockTime = 0
local freeRestockCount = 5                 -- Allow 5 free restocks
local usedFreeRestocks = 0                 -- Counter for used free restocks
local ShopRestockPrice = 5000              -- Initial restock price
local RestockPriceScalingFactor = 1.5      -- Price scaling factor
local MaxPurchasedRestocks = 15            -- Maximum purchased restocks before price reset
local PurchasedRestockCount = 0            -- Counter for purchased restocks

-- Handle the actual restocking part
if onServer() then
    edr_generateSeed = Shop.generateSeed
    function Shop:generateSeed(...)
        if self.staticSeed then
            return edr_generateSeed(self, ...)
        else
            return edr_generateSeed(self, ...) .. edr_specialOfferSeed
        end
    end

    function Shop:remoteRestock()
        edr_specialOfferSeed = edr_specialOfferSeed + 1 -- Call the restock function to update the items
        self:restock()
    end

    edr_CreateNamespace = PublicNamespace.CreateNamespace
    function PublicNamespace.CreateNamespace(...)
        local result = edr_CreateNamespace(...)

        result.remoteRestock = function(...) return result.shop:remoteRestock(...) end

        callable(result, "remoteRestock")

        return result
    end
end

-- Add the button to trigger a restock
if onClient() then
    edr_buildBuyGui = Shop.buildBuyGui
    function Shop:buildBuyGui(tab, config, ...)
        edr_buildBuyGui(self, tab, config, ...)

        -- Defined within the BuildGui function in shop.lua for the Buy buttons
        local x = 720

        -- Create the restock button
        edr_restockButton = tab:createButton(Rect(x, 0, x + 160, 30), "", "edr_onRestockButtonPressed")
        edr_restockButton.icon = "data/textures/icons/clockwise-rotation.png"
        edr_restockButton.tooltip = "Click to restock the shop" % _t
    end

    function Shop:edr_onRestockButtonPressed(button)
        local currentTime = os.time()

        -- Check if the player can restock for free
        if usedFreeRestocks < freeRestockCount then
            -- Allow free restock
            usedFreeRestocks = usedFreeRestocks + 1
            invokeServerFunction("remoteRestock") -- Call the server function to restock
            Player():sendChatMessage(
                "Free restock used. You have " .. (freeRestockCount - usedFreeRestocks) .. " free restocks left.", 1)
        elseif currentTime - lastRestockTime >= restockCooldown then
            -- Cooldown has passed
            lastRestockTime = currentTime         -- Update the last restock time
            invokeServerFunction("remoteRestock") -- Call the server function to restock
            Player():sendChatMessage("Shop restocked. Next restock available in 15 minutes.", 1)
        else
            -- Calculate remaining cooldown time
            local remainingCooldown = restockCooldown - (currentTime - lastRestockTime)
            local minutes = math.floor(remainingCooldown / 60)
            local seconds = remainingCooldown % 60

            -- Provide feedback to the player with remaining cooldown time
            Player():sendChatMessage(
                string.format("Restock is on cooldown for %d minutes and %d seconds. Please wait.", minutes, seconds), 1)
        end
    end

    function Shop:purchaseRestock()
        -- Calculate the current price based on the number of purchased restocks
        local currentPrice = ShopRestockPrice * (RestockPriceScalingFactor ^ PurchasedRestockCount)

        -- Check if the player can afford the restock
        if Player():getMoney() >= currentPrice then
            -- Deduct the restock price from the player's money
            Player():subtractMoney(currentPrice)

            -- Increment the purchased restock counter
            PurchasedRestockCount = PurchasedRestockCount + 1

            -- Restock the shop
            invokeServerFunction("remoteRestock")

            -- Send a chat message to the player indicating the purchase
            Player():sendChatMessage("You just spent " .. currentPrice .. " credits for a shop restock!", 1)

            -- Reset price if the limit is reached
            if PurchasedRestockCount >= MaxPurchasedRestocks then
                PurchasedRestockCount = 0
            end
        else
            -- Display a message indicating that the player cannot afford the restock
            Player():sendChatMessage(
            "You cannot afford to restock. The current price is " .. currentPrice .. " credits.", 1)
        end
    end

    edr_CreateNamespace = PublicNamespace.CreateNamespace
    function PublicNamespace.CreateNamespace(...)
        local result = edr_CreateNamespace(...)
        result.edr_onRestockButtonPressed = function(...) return result.shop:edr_onRestockButtonPressed(...) end
        result.purchaseRestock = function(...) return result.shop:purchaseRestock(...) end
        return result
    end
end
