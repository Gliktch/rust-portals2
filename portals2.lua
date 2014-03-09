PLUGIN.Title = "Portals 2"
PLUGIN.Description = "Lets you place teleportation portals, and assign access to them by flags."
PLUGIN.Author = "greyhawk, Gliktch"
PLUGIN.Version = "0.2"

function PLUGIN:Init()
    print("Loading Portals 2 Mod...")
    self.Radius = 10
	self.DataFile = util.GetDatafile( "portals2" )
	local txt = self.DataFile:GetText()
	if (txt ~= "") then
		self.Data = json.decode( txt )
	else
		self.Data = {}
	end
    self:AddChatCommand( "go", self.cmdGo )
    self:AddChatCommand( "goset", self.cmdGoSet )
    self:AddChatCommand( "gohelp", self.cmdGoHelp )
end

function PLUGIN:PostInit()
    self.oxminPlugin = plugins.Find("oxmin")
    if (self.oxminPlugin) then
        self.FLAG_GOALL = oxmin.AddFlag("goall")
        self.oxminPlugin:AddExternalOxminChatCommand(self, "go", { }, self.cmdGo)
        self.oxminPlugin:AddExternalOxminChatCommand(self, "goset", { self.FLAG_GOALL }, self.cmdGoSet)
        self.oxminPlugin:AddExternalOxminChatCommand(self, "gohelp", { }, self.cmdGoHelp)
    end
    self.flagsPlugin = plugins.Find("flags")
end

function PLUGIN:HasFlag(netuser, flag)
    if (netuser:CanAdmin()) then
        do return true end
    elseif ((self.oxminPlugin ~= nil) and (self.oxminPlugin:HasFlag(netuser, flag))) then
        do return true end
    elseif ((self.flagsPlugin ~= nil) and (self.flagsPlugin:HasFlag(netuser, flag))) then
        do return true end
    end
    return false
end

function PLUGIN:cmdGo( netuser, args )
    -- get netuser coords
    local coords = netuser.playerClient.lastKnownPosition
    
    -- find portal
    local portal = self:getPortalXYZ(coords.x, coords.y, coords.z)
    if (not portal) then
        rust.Notice( netuser, "No go spot around " .. self:printCoord(coords))
        return
    else
        rust.SendChatToUser( netuser, "Found " .. self:printPortal(portal) )
    end
    
    -- find out portal
    local outPortal
    if (portal.Code == "bb") then
        outPortal = self:getPortal(portal.Name, "aa")
    else
        outPortal = self:getPortal(portal.Name, "bb")
    end
    
    if (not outPortal) then
        rust.Notice( netuser, "No target spot found ")
        return
    end
    
    -- flagged portal
    if ( portal.Flag and (not self:HasFlag(netuser, portal.Flag)) and (not self:HasFlag(netuser, "goall"))) then
        rust.Notice( netuser, "You don't have access to this portal!" )
        return
    else
    -- teleport
        coords.x = outPortal.X
        coords.y = outPortal.Y
        coords.z = outPortal.Z
        rust.ServerManagement():TeleportPlayer(netuser.playerClient.netPlayer, coords)
        rust.SendChatToUser( netuser, "Teleported to " .. self:printPortal(outPortal) )
    end
end

function PLUGIN:cmdGoSet( netuser, args )
    if (not self:HasFlag(netuser, "goall")) then
        rust.Notice( netuser, "You don't have permission to set portals." )
        return
    end
    
    -- setportal "name" aa flag
    -- setportal "name" bb flag
    if ( (not args[1]) and (not args[2]) ) then
        rust.SendChatToUser( netuser, "Syntax: /goset \"name\" code flag" )
        rust.SendChatToUser( netuser, "Syntax: code aa or bb (portals are paired)" )
        return
    end
    
    local flag = false
    if ((args[3]) and (type(args[3]) == "string")) then
        flag = (args[3])
    end
    -- get netuser coords
    local coords = netuser.playerClient.lastKnownPosition
    
    -- update/create portal "name" with point aa/bb
    portal = self:getPortal(args[1], args[2])
    if (not portal) then
        portal = self:createPortal(args[1], args[2], coords.x, coords.y, coords.z, flag)
        if (not portal) then
            rust.Notice( netuser, "Failed to create portal!")
            return
        else
            rust.SendChatToUser( netuser, "Created " .. self:printPortal(portal))
        end
    else
        portal = self:updatePortal(args[1], args[2], coords.x, coords.y, coords.z, flag)
        if (not portal) then
            rust.Notice( netuser, "Failed to update portal!")
            return
        else
            rust.SendChatToUser( netuser, "Updated " .. self:printPortal(portal))
        end
    end
    
end

function PLUGIN:getPortalXYZ(x, y, z)
    for key,value in pairs(self.Data) do
        if ( ((value.X + self.Radius > x) and (value.X - self.Radius < x))
         and ((value.Y + self.Radius > y) and (value.Y - self.Radius < y))
         and ((value.Z + self.Radius > z) and (value.Z - self.Radius < z)) ) then
            return value
        end
    end
    return nil
end

function PLUGIN:createPortal(name, code, x, y, z, flag)
    local portal = {}
    portal.Name = name
    portal.X = x
    portal.Y = y
    portal.Z = z
    portal.Code = code
    portal.Flag = flag
    portal.Reserved = {}
    table.insert(self.Data, portal)
    self:Save()
    return portal
end

function PLUGIN:getPortal(name, code)
    for key,value in pairs(self.Data) do
        if ((value.Name == name) and (value.Code == code)) then
            return value
        end
    end
    return nil
end

function PLUGIN:updatePortal(name, code, x, y, z, flag)
    for key,value in pairs(self.Data) do
        if ((value.Name == name) and (value.Code == code)) then
            self.Data[key].Name = name
            self.Data[key].X = x
            self.Data[key].Y = y
            self.Data[key].Z = z
            self.Data[key].Flag = flag
            self.Data[key].Reserved = {}
            self:Save()
            return self.Data[key]
        end
    end
    return nil
end

function PLUGIN:printPortal(portal)
    return ( "Portal " .. portal.Name .. " . " .. portal.Code .. ": " .. self:printPortalCoords(portal) .. ((portal.Flag) and " / Flag: " .. portal.Flag or " / Public") )
end

function PLUGIN:printPortalCoords(portal)
    return ( self:printCoords(portal.X, portal.Y, portal.Z) )
end

function PLUGIN:printCoords(x, y, z)
    return ( "x" .. tostring(x) .. " y" .. tostring(y) .. " z" .. tostring(z) )
end

function PLUGIN:printCoord(coord)
    return ( "x" .. coord.x .. " y" .. coord.y .. " z" .. coord.z )
end

function PLUGIN:cmdGoHelp( netuser )
    rust.SendChatToUser( netuser, "--------------------------------------------------------------------------------" )
    rust.SendChatToUser( netuser, "------------- Greyhawk's Portals Plugin, modded by Gliktch -------------" )
	rust.SendChatToUser( netuser, "Use /go to teleport to a paired portal" )
    if (self:HasFlag(netuser, "goall")) then
        rust.SendChatToUser( netuser, "Use /goset \"name\" code flag" )
        rust.SendChatToUser( netuser, "Syntax: code aa or bb (portals are paired)" )
    end
    rust.SendChatToUser( netuser, "--------------------------------------------------------------------------------" )
end

function PLUGIN:SendHelpText( netuser )
    rust.SendChatToUser( netuser, "Use /go to travel through a portal, if you've been given access." )
end

function PLUGIN:Save()
	self.DataFile:SetText( json.encode( self.Data ) )
	self.DataFile:Save()
end
