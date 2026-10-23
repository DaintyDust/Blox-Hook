local SoundConfig = {
	HookAttach = {
		Id = "rbxassetid://124990410138576",
		--Id = "rbxassetid://118662377115778",
		--Id = "rbxassetid://9120629110",
		Volume = 0.25,
		--PlaybackSpeed = 1.45,
	},
	HookRelease = {
		Id = "",
		--Id = "rbxassetid://9120628323",
		Volume = 0.6,
	},
	MenuPlay = {
		Id = "rbxassetid://105051584535992",
		--Id = "rbxassetid://94537729028560",
		Volume = 0.8,
	},
	NextLevel = {
		Id = "rbxassetid://131618886637413",
		--Id = "rbxassetid://123795444237739",
		Volume = 0.8,
	},
	MenuSelect = {
		Id = "rbxassetid://102984092925698",
		--Id = "rbxassetid://140515349341063",
		Volume = 1,
	},
	FinishLevel = {
		--Id = "rbxassetid://112485797063762",
		Ids = {
			"rbxassetid://139559979773530",
			"rbxassetid://71839929610283",
		},
		Volume = 1,
	},
	BouncePad = {
		Id = "rbxassetid://77052262376066",
		Volume = 0.65,
	},
	Death = {
		Id = "rbxassetid://125730269420964",
		--Id = "rbxassetid://139203439169314",
		--Id = "rbxassetid://9120628904",
		Volume = 0.6,
	},
	Swing = {
		Ids = {
			"rbxassetid://101770091880424",
			"rbxassetid://95877008887735",
			"rbxassetid://94328539101606",
			"rbxassetid://134173701417639",
			--"rbxassetid://9120972323",
			--"rbxassetid://9120972444",
			--"rbxassetid://9120972321",
			--"rbxassetid://9120972724",
			--"rbxassetid://9120972689",
			--"rbxassetid://9117038151",
		},
		Volume = 0.75,
		PlaybackSpeed = 1,
		MinSpeed = 30,
	},
}

return SoundConfig
