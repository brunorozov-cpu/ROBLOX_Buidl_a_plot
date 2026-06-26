local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local Remotes = ReplicatedStorage:WaitForChild("TycoonSystem"):WaitForChild("Remotes")
local SelectPlotRF = Remotes:WaitForChild("SelectPlot")
local PlaceObjectRE = Remotes:WaitForChild("PlaceObject")
local Models = ReplicatedStorage.TycoonSystem.Models

local plotsFolder = workspace:FindFirstChild("Plots") or Instance.new("Folder", workspace)
plotsFolder.Name = "Plots"

local PLOT_COUNT = 4
local plots = {}

local function getPlotByPlayer(player)
	for index, plot in ipairs(plots) do
		if plot.Owner == player then
			return plot, index
		end
	end
	return nil
end

local function getPlotByUserId(userId)
	for index, plot in ipairs(plots) do
		if plot.OwnerUserId == userId then
			return plot, index
		end
	end
	return nil
end

-- Initialize 4 plot slots
for i = 1, PLOT_COUNT do
	plots[i] = {
		Owner = nil,
		OwnerUserId = nil,
		Model = nil,
		Config = nil -- Will store CFrame and BuildArea
	}
end

local function loadPlot(player, slotIndex)
	local plot = plots[slotIndex]
	if not plot or not plot.Config then return end

	if plot.Model then
		plot.Model:Destroy()
	end

	-- Create plot container
	local plotModel = Instance.new("Model")
	plotModel.Name = "Plot_" .. slotIndex .. "_" .. player.Name
	plotModel.Parent = plotsFolder
	plot.Model = plotModel

	local data = DataManager.LoadPlayerData(player)
	if data and data.Objects then
		for _, objData in pairs(data.Objects) do
			local template = Models:FindFirstChild(objData.Name)
			if template then
				local newObj = template:Clone()
				newObj:SetPrimaryPartCFrame(plot.Config.CFrame * CFrame.new(unpack(objData.RelativePos)))
				newObj.Parent = plotModel
			end
		end
	end
end

SelectPlotRF.OnServerInvoke = function(player, slotIndex)
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > PLOT_COUNT then
		return false, "Invalid slot"
	end

	local requestedPlot = plots[slotIndex]
	if not requestedPlot or not requestedPlot.Config then
		return false, "Slot not configured"
	end

	local existingPlot, existingIndex = getPlotByUserId(player.UserId)
	if existingPlot and existingPlot ~= requestedPlot then
		return false, "Already own a plot"
	end

	if requestedPlot.OwnerUserId and requestedPlot.OwnerUserId ~= player.UserId then
		return false, "Slot taken"
	end

	requestedPlot.Owner = player
	requestedPlot.OwnerUserId = player.UserId
	loadPlot(player, slotIndex)
	return true, requestedPlot.Config
end

PlaceObjectRE.OnServerEvent:Connect(function(player, modelName, relativeCFrame)
	if type(modelName) ~= "string" or typeof(relativeCFrame) ~= "CFrame" then
		return
	end

	local playerPlot = getPlotByPlayer(player) or getPlotByUserId(player.UserId)
	if not playerPlot or not playerPlot.Config then
		return
	end

	local relativePos = relativeCFrame.Position
	local halfArea = playerPlot.Config.BuildArea / 2
	if math.abs(relativePos.X) > halfArea.X or math.abs(relativePos.Y) > halfArea.Y or math.abs(relativePos.Z) > halfArea.Z then
		return
	end

	local worldCFrame = playerPlot.Config.CFrame * relativeCFrame
	local template = Models:FindFirstChild(modelName)
	if template then
		local newObj = template:Clone()
		newObj:SetPrimaryPartCFrame(worldCFrame)
		newObj.Parent = playerPlot.Model

		local currentData = DataManager.LoadPlayerData(player) or {Objects = {}}
		currentData.Objects = currentData.Objects or {}
		table.insert(currentData.Objects, {
			Name = modelName,
			RelativePos = {relativeCFrame:GetComponents()}
		})
		DataManager.SavePlayerData(player, currentData)
	end
end)

Players.PlayerAdded:Connect(function(player)
	local plot, index = getPlotByUserId(player.UserId)
	if plot then
		plot.Owner = player
		if not plot.Model then
			loadPlot(player, index)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local plot = getPlotByPlayer(player)
	if plot then
		if plot.Model then
			plot.Model:Destroy()
			plot.Model = nil
		end
		plot.Owner = nil
	end
end)

-- Function to be called by Admin Script to set up plots
local function setupPlotLocations()
	local configFolder = workspace:FindFirstChild("PlotConfigs")
	if configFolder then
		local children = configFolder:GetChildren()
		table.sort(children, function(a, b)
			return a.Name < b.Name
		end)
		for i = 1, math.min(#children, PLOT_COUNT) do
			local part = children[i]
			plots[i].Config = {
				CFrame = part.CFrame,
				Size = part.Size,
				BuildArea = part:GetAttribute("BuildArea") or part.Size
			}
		end
	end
end

-- Listen for admin updates
workspace.ChildAdded:Connect(function(child)
	if child.Name == "PlotConfigs" then
		setupPlotLocations()
	end
end)
setupPlotLocations()

return {} -- To satisfy script requirements if needed
