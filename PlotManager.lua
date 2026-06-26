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

-- Initialize 4 plot slots
for i = 1, PLOT_COUNT do
	plots[i] = {
		Owner = nil,
		Model = nil,
		Config = nil -- Will store CFrame and BuildArea
	}
end

local function loadPlot(player, slotIndex)
	local plot = plots[slotIndex]
	if not plot or not plot.Config then return end
	
	local data = DataManager.LoadPlayerData(player)
	
	-- Create plot container
	local plotModel = Instance.new("Model")
	plotModel.Name = "Plot_" .. player.Name
	plotModel.Parent = plotsFolder
	plot.Model = plotModel
	
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
	if slotIndex < 1 or slotIndex > PLOT_COUNT then return false, "Invalid slot" end
	
	-- Check if player already has a plot
	for _, p in pairs(plots) do
		if p.Owner == player then return false, "Already own a plot" end
	end
	
	local plot = plots[slotIndex]
	if plot.Owner == nil and plot.Config then
		plot.Owner = player
		loadPlot(player, slotIndex)
		return true, plot.Config
	end
	
	return false, "Slot taken or not configured"
end

PlaceObjectRE.OnServerEvent:Connect(function(player, modelName, relativeCFrame)
	local playerPlot = nil
	local plotIndex = 0
	for iStep, p in pairs(plots) do
		if p.Owner == player then
			playerPlot = p
			plotIndex = iStep
			break
		end
	end
	
	if not playerPlot or not playerPlot.Config then return end
	
	-- Boundary check (simplified for now)
	local worldCFrame = playerPlot.Config.CFrame * relativeCFrame
	
	local template = Models:FindFirstChild(modelName)
	if template then
		local newObj = template:Clone()
		newObj:SetPrimaryPartCFrame(worldCFrame)
		newObj.Parent = playerPlot.Model
		
		-- Simple auto-save (ideally throttled)
		local currentData = DataManager.LoadPlayerData(player) or {Objects = {}}
		table.insert(currentData.Objects, {
			Name = modelName,
			RelativePos = {relativeCFrame:GetComponents()}
		})
		DataManager.SavePlayerData(player, currentData)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for i = 1, PLOT_COUNT do
		if plots[i].Owner == player then
			if plots[i].Model then
				plots[i].Model:Destroy()
			end
			plots[i].Owner = nil
			plots[i].Model = nil
			break
		end
	end
end)

-- Function to be called by Admin Script to set up plots
local function setupPlotLocations()
	local configFolder = workspace:FindFirstChild("PlotConfigs")
	if configFolder then
		local children = configFolder:GetChildren()
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
