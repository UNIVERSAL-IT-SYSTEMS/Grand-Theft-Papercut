local inspect = require "lib.inspect"
local serialize = require "lib.ser"
local cron = require "lib.cron"

local lg = love.graphics
local lk = love.keyboard

local tiles, tileset -- loaded in love.load

local scale = 2
local tileSize = 16 * scale

local player = {
    x = 9,
    y = 7,
    image = false --loaded after fixing image filter
}

local camera = {
    -- these are top left corner values
    x = 1,
    y = 1
}

function love.load()
    lg.setDefaultFilter("linear", "nearest", 1)
    player.image = lg.newImage("dude.png")

    tiles = require "tiles"
    tileset = require "tileset"
end

function love.draw()
    for x=camera.x,camera.x+14 do
        for y=camera.y,camera.y+9 do
            if tiles[x] and tiles[x][y] then
                lg.draw(tileset[tiles[x][y]], (x - camera.x) * tileSize, (y - camera.y) * tileSize, 0, scale, scale)
            end
        end
    end

    lg.draw(player.image, (player.x - camera.x) * tileSize, (player.y - camera.y) * tileSize, 0, scale, scale)
end

local movement, lastKeys = false, {}
local function move()
    local moved

    if lk.isDown("w") and lastKeys[1] == "w" and tileset.isWalkable(tiles[player.x][player.y-1]) then
        player.y = player.y - 1
        moved = true
    end
    if lk.isDown("a") and lastKeys[1] == "a" and tiles[player.x-1] and tileset.isWalkable(tiles[player.x-1][player.y]) then
        player.x = player.x - 1
        moved = true
    end
    if lk.isDown("s") and lastKeys[1] == "s" and tileset.isWalkable(tiles[player.x][player.y+1]) then
        player.y = player.y + 1
        moved = true
    end
    if lk.isDown("d") and lastKeys[1] == "d" and tiles[player.x+1] and tileset.isWalkable(tiles[player.x+1][player.y]) then
        player.x = player.x + 1
        moved = true
    end

    if moved then
        if math.abs(player.x - camera.x) < 5 then
            camera.x = camera.x - 1
        elseif math.abs(player.x - camera.x) > 9 then
            camera.x = camera.x + 1
        elseif math.abs(player.y - camera.y) < 3 then
            camera.y = camera.y - 1
        elseif math.abs(player.y - camera.y) > 6 then
            camera.y = camera.y + 1
        end

        movement = cron.after(1/6, move)
    end
end

function love.update(dt)
    if movement then movement:update(dt) end
end

function love.keypressed(key, unicode)
    table.insert(lastKeys, 1, key) -- we save the last key pressed

    if key == "escape" then
        love.event.quit()
    end

    move()
end

function love.keyreleased(key)
    --find key in lastKeys and remove it
    for i=#lastKeys,1,-1 do
        if lastKeys[i] == key then
            table.remove(lastKeys, i)
        end
    end
    print(inspect(lastKeys))
end

local function maketile(x, y)
    if not tiles[x] then
        tiles[x] = {}
        if x < tiles.minX then
            tiles.minX = x
        elseif x > tiles.maxX then
            tiles.maxX = x
        end
    end
    if not tiles[x][y] then
        tiles[x][y] = 0
        if y < tiles.minY then
            tiles.minY = y
        elseif y > tiles.maxY then
            tiles.maxY = y
        end
    end
end

local selectedTile = 0
function love.mousepressed(x, y, button)
    x = math.floor(x / tileSize) + camera.x
    y = math.floor(y / tileSize) + camera.y

    maketile(x, y)

    if button == "wu" then
        tiles[x][y] = tiles[x][y] - 1
        if tiles[x][y] < 0 then
            tiles[x][y] = tileset.count
        end
    elseif button == "wd" then
        tiles[x][y] = tiles[x][y] + 1
        if tiles[x][y] > tileset.count then
            tiles[x][y] = 0
        end
    elseif button == "r" then
        selectedTile = tiles[x][y]
    elseif button == "l" then
        tiles[x][y] = selectedTile
    end
end

local next = next

function love.quit()
    for x=tiles.minX,tiles.maxX do
        for y=tiles.minY,tiles.maxY do
            if tiles[x] and tiles[x][y] == 0 then
                tiles[x][y] = nil
            end
        end
        if next(tiles[x]) == nil then
            tiles[x] = nil
            if x == tiles.minX then
                tiles.minX = x + 1
            end
        end
    end
    tiles.maxX = #tiles
    collectgarbage()
    -- dunno how to check / set minY and maxY (well, I do, but it would be time-consuming and boring)
    love.filesystem.write("tiles.lua", serialize(tiles))
end