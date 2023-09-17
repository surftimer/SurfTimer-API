
/* Deals with all(?) POST callbacks */
public void apiPostCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();

	PrintToServer("[Surf API] Status (%s): %i", func, response.Status);

	if (response.Status != HTTPStatus_Created)
	{
		delete data;
		if (response.Status == HTTPStatus_NotModified)
		{
			LogError("[Surf API] Could not CREATE item. Status %i (%s)", response.Status, func);
			return;
		}
		LogError("[Surf API] POST callback error. Status %i (%s)", response.Status, func);
		return;
	}

	// Assign the response to a JSONObject
	JSONObject jsonObject = view_as<JSONObject>(response.Data);

	// Assign the values from the JSONObject to variables
	// float	   xtime	  = jsonObject.GetFloat("xtime");
	// int		   inserted	  = jsonObject.GetInt("inserted");

	if (StrEqual(func, "db_insertMapTier"))
	{
		db_selectMapTier();
	}
	else if (StrEqual(func, "db_insertBonus"))
	{
		int client = data.ReadCell();
		int zgroup = data.ReadCell();

		db_viewMapRankBonus(client, zgroup, 1);
		// Change to update profile timer, if giving multiplier count or extra points for bonuses
		CalculatePlayerRank(client, 0);
	}
	else if (StrEqual(func, "db_InsertLatestRecords"))
	{
		char  sTime[64], steamId[64];
		float runTime = data.ReadFloat();
		data.ReadString(steamId, sizeof(steamId));
		FormatTimeFloat(0, runTime, 3, sTime, sizeof(sTime));
	}
	else if (StrEqual(func, "sql_insertPlayerOptions-cb-nested"))
	{
		// char  sTime[64], steamId[64];
		// float runTime = data.ReadFloat();
		// data.ReadString(steamId, sizeof(steamId));
		// FormatTimeFloat(0, runTime, 3, sTime, sizeof(sTime));
	}
	else if (StrEqual(func, "api_insertPlayerRank"))
	{
		int client = data.ReadCell();
		if (IsClientInGame(client))
			db_UpdateLastSeen(client);
	}
	else if (StrEqual(func, "api_insertPlayerRank2"))
	{
		int client				 = data.ReadCell();

		// Play time
		g_iPlayTimeAlive[client] = 0;
		g_iPlayTimeSpec[client]	 = 0;

		// Count players rank
		for (int i = 0; i < MAX_STYLES; i++)
			db_GetPlayerRank(client, i);
	}

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
	// Delete objects so we avoid memory leaks
	delete jsonObject;
	delete data;
	return;
}

/* Deals with all(?) PUT callbacks */
public void apiPutCallback(HTTPResponse response, DataPack data)
{
	char func[256];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	PrintToServer("[Surf API] Status (%s): %i", func, response.Status);

	if (response.Status == HTTPStatus_NotModified)
	{
		if (!StrEqual(func, "api_updatePlayerRankPoints-AdminMenu", false))	   // shouldn't `return` if we recalculating points from menu
		{
			LogQueryTime("[Surf API] Could not UPDATE item. Status %i (%s)", response.Status, func);
			delete data;
			return;
		}
	}
	else if (response.Status != HTTPStatus_OK)
	{
		LogError("[Surf API] PUT callback error. Status %i (%s)", response.Status, func);
		delete data;
		return;
	}

	if (response.Status == HTTPStatus_OK)
	{
		// Assign the response to a JSONObject
		JSONObject jsonObject = view_as<JSONObject>(response.Data);

		float	   xtime	  = jsonObject.GetFloat("xtime");
		int		   updated	  = jsonObject.GetInt("updated");
		PrintToServer("[Surf API - %s] Updated %i in %.4f", func, updated, xtime);

		delete jsonObject;
	}

	if (StrEqual(func, "db_insertMapperName") || StrEqual(func, "db_insertMapTier"))
	{
		db_selectMapTier();
	}
	else if (StrEqual(func, "db_updateBonus"))
	{
		int client = data.ReadCell();
		int zgroup = data.ReadCell();

		db_viewMapRankBonus(client, zgroup, 2);
		CalculatePlayerRank(client, 0);
	}
	else if (StrEqual(func, "db_updatePlayerOptions"))
	{
	}
	else if (StrEqual(func, "db_updateStat"))
	{
		int client = data.ReadCell();
		int style  = data.ReadCell();

		// Calculating starts here:
		CalculatePlayerRank(client, style);
	}
	else if (StrEqual(func, "api_updatePlayerRankPoints-AdminMenu") || StrEqual(func, "api_updatePlayerRankPoints2"))	 // Recalculates points
	{
		int client = data.ReadCell();
		int style  = data.ReadCell();
		PrintToServer("[Surf API] api_updatePlayerRankPoints callback starts / recalculating stuff");

		// If was recalculating points, go to the next player, announce or end calculating
		if (client > MAXPLAYERS && g_pr_RankingRecalc_InProgress || client > MAXPLAYERS && g_bProfileRecalc[client])
		{
			if (g_bProfileRecalc[client] && !g_pr_RankingRecalc_InProgress)
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						if (StrEqual(g_szSteamID[i], g_pr_szSteamID[client]))
							CalculatePlayerRank(i, 0);
					}
				}
			}

			g_bProfileRecalc[client] = false;
			if (g_pr_RankingRecalc_InProgress)
			{
				// console info
				if (IsValidClient(g_pr_Recalc_AdminID) && g_bManualRecalc)
					PrintToConsole(g_pr_Recalc_AdminID, "%i/%i", g_pr_Recalc_ClientID, g_pr_TableRowCount);

				int x = 66 + g_pr_Recalc_ClientID;
				if (StrContains(g_pr_szSteamID[x], "STEAM", false) != -1)
				{
					ContinueRecalc(x);
				}
				else
				{
					for (int i = 1; i <= MaxClients; i++)
						if (1 <= i <= MaxClients && IsValidEntity(i) && IsValidClient(i))
						{
							if (g_bManualRecalc)
								CPrintToChat(i, "%t", "PrUpdateFinished", g_szChatPrefix);
						}

					g_bManualRecalc				  = false;
					g_pr_RankingRecalc_InProgress = false;

					if (IsValidClient(g_pr_Recalc_AdminID))
						CreateTimer(0.1, RefreshAdminMenu, g_pr_Recalc_AdminID, TIMER_FLAG_NO_MAPCHANGE);
				}
				g_pr_Recalc_ClientID++;
			}
		}
		else	// Gaining points normally
		{
			// Player recalculated own points in !profile
			if (g_bRecalcRankInProgess[client] && client <= MAXPLAYERS)
			{
				ProfileMenu2(client, style, "", g_szSteamID[client]);
				if (IsValidClient(client))
				{
					if (style == 0)
						CPrintToChat(client, "%t", "Rc_PlayerRankFinished", g_szChatPrefix, g_pr_points[client][style]);
					else
						CPrintToChat(client, "%t", "Rc_PlayerRankFinished2", g_szChatPrefix, g_szStyleMenuPrint[style], g_pr_points[client][style]);
				}

				g_bRecalcRankInProgess[client] = false;
			}
			if (IsValidClient(client) && g_pr_showmsg[client])	  // Player gained points
			{
				char szName[MAX_NAME_LENGTH];
				GetClientName(client, szName, MAX_NAME_LENGTH);

				int diff = g_pr_points[client][style] - g_pr_oldpoints[client][style];
				if (diff > 0)	 // if player earned points -> Announce
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i))
						{
							if (style == 0)
								CPrintToChat(i, "%t", "EarnedPoints", g_szChatPrefix, szName, diff, g_pr_points[client][0]);
							else
								CPrintToChat(i, "%t", "EarnedPoints2", g_szChatPrefix, szName, diff, g_szStyleRecordPrint[style], g_pr_points[client][style]);
						}
					}
				}

				g_pr_showmsg[client] = false;
				db_CalculatePlayersCountGreater0(style);
			}
			g_pr_Calculating[client] = false;
			db_GetPlayerRank(client, style);
			CreateTimer(1.0, SetClanTag, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if (StrEqual(func, "db_updateStat"))
	{
	}

	LogQueryTime("====== [Surf API] : Finished %s in: %.4f", func, GetGameTime() - fTime);
	delete data;
	return;
}

/* Deals with all(?) DELETE callbacks */
public void apiDeleteCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	PrintToServer("[Surf API] Status (%s): %i", func, response.Status);

	if (response.Status != HTTPStatus_OK)
	{
		delete data;
		if (response.Status == HTTPStatus_NotModified)
		{
			LogError("[Surf API] Could not DELETE item. Status %i (%s)", response.Status, func);
			return;
		}
		LogError("[Surf API] DELETE callback error. Status %i (%s)", response.Status, func);
		return;
	}

	// Assign the response to a JSONObject
	JSONObject jsonObject = view_as<JSONObject>(response.Data);

	float	   xtime	  = jsonObject.GetFloat("xtime");
	int		   deleted	  = jsonObject.GetInt("deleted");
	PrintToServer("[Surf API - %s] Deleted %i in %.4f", func, deleted, xtime);

	// Use the values from the API response
	LogQueryTime("====== [Surf API] : Finished %s in: %.4f", func, GetGameTime() - fTime);

	// if (StrEqual(func, "db_deleteCheckpoints") || StrEqual(func, "db_deleteBonus"))

	// Delete objects so we avoid memory leaks
	delete jsonObject;
	delete data;
	return;
}

/* ck_latestrecords */
public void apiViewLatestRecordsCallback(HTTPResponse response, DataPack data)
{
	int	  client = data.ReadCell();
	char  func[128];
	float fTime = data.ReadFloat();
	data.ReadString(func, sizeof(func));
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] Map not found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error (%s)", func);
		return;
	}

	PrintToServer("[Surf API] Status (%s): %i", func, response.Status);
	PrintToConsole(client, "----------------------------------------------------------------------------------------------------");
	PrintToConsole(client, "Last map records:");

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	// PrintToServer("Array Length: %i", jsonArray.Length);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		// LogError("[Surf-API] API Returned empty array");
		PrintToConsole(client, "No records found.");
		PrintToConsole(client, "----------------------------------------------------------------------------------------------------");
		delete jsonArray;
		return;
	}

	char  szName[64];
	char  szMapName[64];
	char  szDate[64];
	char  szTime[32];
	float ftime;

	Menu  menu = CreateMenu(LatestRecordsMenuHandler);
	SetMenuTitle(menu, "Recently Broken Records");

	int loopIdx = 0;
	for (int i = 0; i < jsonArray.Length; i++)
	{
		char	   szItem[128];
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));

		jsonObject.GetString("name", szName, sizeof(szName));
		jsonObject.GetString("map", szMapName, sizeof(szMapName));
		jsonObject.GetString("date", szDate, sizeof(szDate));
		ftime = jsonObject.GetFloat("runtime");
		FormatTimeFloat(client, ftime, 3, szTime, sizeof(szTime));

		Format(szItem, sizeof(szItem), "%s - %s by %s (%s)", szMapName, szTime, szName, szDate);

		PrintToConsole(client, szItem);
		AddMenuItem(menu, "", szItem, ITEMDRAW_DISABLED);
		loopIdx++;
		delete jsonObject;
	}

	delete jsonArray;

	if (loopIdx != 0)
	{
		SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		PrintToConsole(client, "No records found.");
		delete menu;
	}

	PrintToConsole(client, "No records found.");
	PrintToConsole(client, "----------------------------------------------------------------------------------------------------");
	CPrintToChat(client, "%t", "ConsoleOutput", g_szChatPrefix);
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

/* ck_maptier */
public void apiSelectMapTierCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float time = data.ReadFloat();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		g_bTierEntryFound = false;
		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] Map not found (%s)", func);
			return;
		}

		if (!g_bServerDataLoaded) db_viewRecordCheckpointInMap();

		LogError("[Surf API] API Error (%s)", func);

		return;
	}
	g_bRankedMap		  = false;
	g_bTierEntryFound	  = true;

	JSONObject jsonObject = view_as<JSONObject>(response.Data);
	jsonObject.ToString(out, sizeof(out));
	PrintToServer("[Surf API] Output (%s): %s", func, out);
	int	 tier	= jsonObject.GetInt("tier");
	int	 ranked = jsonObject.GetInt("ranked");
	char mapper[64];
	jsonObject.GetString("mapper", mapper, sizeof(mapper));

	g_bRankedMap = view_as<bool>(ranked);

	if (strlen(mapper) <= 0)
	{
		g_szMapperName	   = "N/A";
		g_bMapperNameFound = false;
	}
	else
	{
		FormatEx(g_szMapperName, sizeof(g_szMapperName), "%s", mapper);
		g_bMapperNameFound = true;
	}

	if (0 < tier < 9)
	{
		g_bTierFound = true;
		g_iMapTier	 = tier;
		if (g_bMapperNameFound)
		{
			Format(g_sTierString, 512, "%c%s \x01by \x03%s %c- ", BLUE, g_szMapName, g_szMapperName, WHITE);
		}
		else
		{
			Format(g_sTierString, 512, "%c%s %c- ", BLUE, g_szMapName, WHITE);
		}

		switch (tier)
		{
			case 1: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, GRAY, tier, WHITE);
			case 2: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, LIGHTBLUE, tier, WHITE);
			case 3: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, BLUE, tier, WHITE);
			case 4: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, DARKBLUE, tier, WHITE);
			case 5: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, RED, tier, WHITE);
			case 6: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, DARKRED, tier, WHITE);
			case 7: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, ORCHID, tier, WHITE);
			case 8: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, PURPLE, tier, WHITE);
			default: Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, GRAY, tier, WHITE);
		}
		if (g_bhasStages)
			Format(g_sTierString, 512, "%s%c%i Stages", g_sTierString, LIGHTGREEN, (g_mapZonesTypeCount[0][3] + 1));
		else
			Format(g_sTierString, 512, "%s%cLinear", g_sTierString, LIMEGREEN);

		if (g_bhasBonus)
			if (g_mapZoneGroupCount > 2)
				Format(g_sTierString, 512, "%s %c-%c %i Bonuses", g_sTierString, WHITE, ORANGE, (g_mapZoneGroupCount - 1));
			else
				Format(g_sTierString, 512, "%s %c-%c Bonus", g_sTierString, WHITE, ORANGE, (g_mapZoneGroupCount - 1));
	}

	if (!g_bServerDataLoaded)
		db_viewRecordCheckpointInMap();

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
}

/* ck_checkpoints */
public void apiSelectCheckpointsCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	if (!IsValidClient(client))
		return;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bSettingsLoaded[client])
			LoadClientSetting(client, g_iSettingToLoad[client]);
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] Map not found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error (%s)", func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject							  = view_as<JSONObject>(jsonArray.Get(i));
		int		   zoneGrp								  = jsonObject.GetInt("zonegroup");
		int		   cp									  = jsonObject.GetInt("cp");
		float	   time									  = jsonObject.GetFloat("time");
		g_bCheckpointsFound[zoneGrp][client]			  = true;
		g_fCheckpointTimesRecord[zoneGrp][client][cp - 1] = time;

		delete jsonObject
	}
	delete jsonArray;

	if (!g_bSettingsLoaded[client])
	{
		g_fTick[client][1] = GetGameTime();
		float tick		   = g_fTick[client][1] - g_fTick[client][0];
		LogQueryTime("====== [Surf API] %s: Finished db_viewCheckpoints in %fs", g_szSteamID[client], tick);
		LoadClientSetting(client, g_iSettingToLoad[client]);
	}

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectCheckpointsInZonegroupCallback(HTTPResponse response, DataPack data)
{
	char  func[128], out[1024];
	int	  client = data.ReadCell();
	float fTime	 = data.ReadFloat();
	data.ReadString(func, sizeof(func));
	int zonegrp = data.ReadCell();
	delete data;

	if (!IsValidClient(client))
		return;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			g_bCheckpointsFound[zonegrp][client] = false;
			return;
		}
		LogError("[Surf API] API Error (%s)", func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject							  = view_as<JSONObject>(jsonArray.Get(i));
		int		   cp									  = jsonObject.GetInt("cp");
		float	   time									  = jsonObject.GetFloat("time");
		g_bCheckpointsFound[zonegrp][client]			  = true;
		g_fCheckpointTimesRecord[zonegrp][client][cp - 1] = time;

		delete jsonObject
	}

	if (g_bhasStages)
		db_LoadCCP(client);

	delete jsonArray;

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectRecordCheckpointCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bServerDataLoaded)
			db_CalcAvgRunTime();

		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}

		LogError("[Surf API] API Error (%s)", func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
		int		   zonegroup  = jsonObject.GetInt("zonegroup");
		int		   cp		  = jsonObject.GetInt("cp");
		float	   time		  = jsonObject.GetFloat("time");
		if (zonegroup == 0)
		{
			g_fCheckpointServerRecord[zonegroup][cp - 1] = time;
			if (!g_bCheckpointRecordFound[zonegroup] && g_fCheckpointServerRecord[zonegroup][cp - 1] > 0.0)
				g_bCheckpointRecordFound[zonegroup] = true;
		}

		delete jsonObject
	}

	if (!g_bServerDataLoaded)
		db_CalcAvgRunTime();

	delete jsonArray;

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectStageTimesCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		if (!g_bSettingsLoaded[client])
			LoadClientSetting(client, g_iSettingToLoad[client]);

		LogError("[Surf API] API Error (%s)", func);
		return;
	}

	if (!IsValidClient(client))
		return;

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	g_bStageTimesFound[client] = true;

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject				   = view_as<JSONObject>(jsonArray.Get(i));
		int		   cp						   = jsonObject.GetInt("cp");
		float	   time						   = jsonObject.GetFloat("stage_time");
		g_fCCPStageTimesRecord[client][cp - 1] = time;

		delete jsonObject
	}

	db_LoadStageAttempts(client);

	delete jsonArray;

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectStageAttemptsCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		if (!g_bSettingsLoaded[client])
			LoadClientSetting(client, g_iSettingToLoad[client]);

		LogError("[Surf API] API Error (%s)", func);
		return;
	}

	if (!IsValidClient(client))
		return;

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		g_bStageAttemptsFound[client]			  = true;

		JSONObject jsonObject					  = view_as<JSONObject>(jsonArray.Get(i));
		int		   cp							  = jsonObject.GetInt("cp");
		int		   attempts						  = jsonObject.GetInt("stage_attempts");
		g_iCCPStageAttemptsRecord[client][cp - 1] = attempts;

		delete jsonObject
	}

	if (!g_bSettingsLoaded[client])
		LoadClientSetting(client, g_iSettingToLoad[client]);

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

/* ck_bonus */
public void apiSelectBonusTotalCountCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bServerDataLoaded)
			db_selectMapTier();

		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	for (int i = 1; i < MAXZONEGROUPS; i++)
		g_iBonusCount[i] = 0;

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
		int		   zonegroup  = jsonObject.GetInt("zonegroup");
		int		   style	  = jsonObject.GetInt("style");
		int		   count	  = jsonObject.GetInt("count(1)");

		if (style == 0)
			g_iBonusCount[zonegroup] = count;
		else
			g_iStyleBonusCount[style][zonegroup] = count;

		delete jsonObject
	}

	if (!g_bServerDataLoaded)
		db_selectMapTier();

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectPersonalBonusCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	for (int i = 0; i < MAXZONEGROUPS; i++)
	{
		g_fPersonalRecordBonus[i][client] = 0.0;
		Format(g_szPersonalRecordBonus[i][client], 64, "N/A");
		for (int s = 1; s < MAX_STYLES; s++)
		{
			g_fStylePersonalRecordBonus[s][i][client] = 0.0;
			Format(g_szStylePersonalRecordBonus[s][i][client], 64, "N/A");
		}
	}

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bSettingsLoaded[client])
			LoadClientSetting(client, g_iSettingToLoad[client]);

		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}

		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
		float	   runTime	  = jsonObject.GetFloat("runtime");
		int		   zgroup	  = jsonObject.GetInt("zonegroup");
		int		   style	  = jsonObject.GetInt("style");

		if (style == 0)
		{
			g_fPersonalRecordBonus[zgroup][client] = runTime;

			if (g_fPersonalRecordBonus[zgroup][client] > 0.0)
			{
				FormatTimeFloat(client, g_fPersonalRecordBonus[zgroup][client], 3, g_szPersonalRecordBonus[zgroup][client], 64);
				db_viewMapRankBonus(client, zgroup, 0);	   // get rank
			}
			else
			{
				Format(g_szPersonalRecordBonus[zgroup][client], 64, "N/A");
				g_fPersonalRecordBonus[zgroup][client] = 0.0;
			}
		}
		else
		{
			g_fStylePersonalRecordBonus[style][zgroup][client] = runTime;

			if (g_fStylePersonalRecordBonus[style][zgroup][client] > 0.0)
			{
				FormatTimeFloat(client, g_fStylePersonalRecordBonus[style][zgroup][client], 3, g_szStylePersonalRecordBonus[style][zgroup][client], 64);
				db_viewMapRankBonusStyle(client, zgroup, 0, style);
			}
			else
			{
				Format(g_szPersonalRecordBonus[zgroup][client], 64, "N/A");
				g_fPersonalRecordBonus[zgroup][client] = 0.0;
			}
		}

		delete jsonObject
	}

	if (!g_bSettingsLoaded[client])
		LoadClientSetting(client, g_iSettingToLoad[client]);

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectPlayerRankBonus(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  zgroup = data.ReadCell();
	int	  type	 = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}

		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		g_MapRankBonus[zgroup][client] = 9999999;
		LogQueryTime("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	// char out[1024];
	// jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	g_MapRankBonus[zgroup][client] = jsonArray.Length;
	char szUName[MAX_NAME_LENGTH * 2 + 1];
	GetClientName(client, szUName, MAX_NAME_LENGTH * 2 + 1);

	char szName[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);

	switch (type)
	{
		case 1:
		{
			g_iBonusCount[zgroup]++;
			PrintChatBonus(client, zgroup);
		}
		case 2:
		{
			PrintChatBonus(client, zgroup);
		}
	}

	// for (int i = 0; i < jsonArray.Length; i++)
	// {
	// 	JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
	// 	char name[MAX_NAME_LENGTH];

	// 	delete jsonObject
	// }

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectFastestBonusCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bServerDataLoaded)
		{
			db_viewBonusTotalCount();
		}

		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}

		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	for (int i = 0; i < MAXZONEGROUPS; i++)
	{
		Format(g_szBonusFastestTime[i], 64, "N/A");
		g_fBonusFastest[i] = 9999999.0;

		for (int s = 0; s < MAX_STYLES; s++)
		{
			if (s != 0)
			{
				Format(g_szStyleBonusFastestTime[s][i], 64, "N/A");
				g_fStyleBonusFastest[s][i] = 9999999.0;
			}

			g_iRecordPreStrafeBonus[0][i][s] = 0;
			g_iRecordPreStrafeBonus[1][i][s] = 0;
			g_iRecordPreStrafeBonus[2][i][s] = 0;
		}
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	// char out[1024];
	// jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject  = view_as<JSONObject>(jsonArray.Get(i));
		// char	   name[MAX_NAME_LENGTH];
		// jsonObject.GetString("name", name, sizeof(name));
		float	   runTime	   = jsonObject.GetFloat("runtime");
		int		   zonegroup   = jsonObject.GetInt("zonegroup");
		int		   style	   = jsonObject.GetInt("style");
		int		   velStartXY  = jsonObject.GetInt("velStartXY");
		int		   velStartXYZ = jsonObject.GetInt("velStartXYZ");
		int		   velStartZ   = jsonObject.GetInt("velstartZ");

		if (style == 0)
		{
			jsonObject.GetString("name", g_szBonusFastest[zonegroup], sizeof(g_szBonusFastest));
			g_fBonusFastest[zonegroup] = runTime;
			FormatTimeFloat(1, g_fBonusFastest[zonegroup], 3, g_szBonusFastestTime[zonegroup], sizeof(g_szBonusFastestTime));
		}
		else
		{
			jsonObject.GetString("name", g_szStyleBonusFastest[style][zonegroup], sizeof(g_szStyleBonusFastest));
			g_fStyleBonusFastest[style][zonegroup] = runTime;
			FormatTimeFloat(1, g_fStyleBonusFastest[style][zonegroup], 3, g_szStyleBonusFastestTime[style][zonegroup], sizeof(g_szStyleBonusFastestTime));
		}

		g_iRecordPreStrafeBonus[0][zonegroup][style] = velStartXY;
		g_iRecordPreStrafeBonus[1][zonegroup][style] = velStartXYZ;
		g_iRecordPreStrafeBonus[2][zonegroup][style] = velStartZ;

		delete jsonObject
	}

	for (int i = 0; i < MAXZONEGROUPS; i++)
	{
		if (g_fBonusFastest[i] == 0.0)
			g_fBonusFastest[i] = 9999999.0;

		for (int s = 1; s < MAX_STYLES; s++)
		{
			if (g_fStyleBonusFastest[s][i] == 0.0)
				g_fStyleBonusFastest[s][i] = 9999999.0;
		}
	}

	if (!g_bServerDataLoaded)
	{
		db_viewBonusTotalCount();
	}

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectAllBonusTimesInMapCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	delete data;

	for (int i = 1; i < MAXZONEGROUPS; i++)
		g_fAvg_BonusTime[i] = 0.0;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bServerDataLoaded)
			db_CalculatePlayerCount(0);

		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	for (int i = 0; i < jsonArray.Length; i++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
		int		   zgrp		  = jsonObject.GetInt("zonegroup");
		float	   apiRunTime = jsonObject.GetFloat("runtime");

		int		   zonegroup, runtimes[MAXZONEGROUPS];
		float	   runtime[MAXZONEGROUPS], time;
		zonegroup = zgrp;
		time	  = apiRunTime;
		if (time > 0.0)
		{
			runtime[zonegroup] += time;
			runtimes[zonegroup]++;
		}

		for (int k = 1; k < MAXZONEGROUPS; k++)
			g_fAvg_BonusTime[k] = runtime[k] / runtimes[k];

		delete jsonObject
	}

	if (!g_bServerDataLoaded)
		db_CalculatePlayerCount(0);

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

public void apiSelectBonusTopSurfersCallback(HTTPResponse response, DataPack data)
{
	char func[128], szMap[128];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	data.ReadString(szMap, sizeof(szMap));
	int zGrp = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	char  szFirstMap[128], szValue[128], szName[64], szSteamID[32], title[256];
	float time;
	Menu  topMenu;

	topMenu				= new Menu(MapMenuHandler1);

	topMenu.Pagination	= 5;

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		CPrintToChat(client, "%t", "NoTopRecords", g_szChatPrefix, g_szMapName);

		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	// char out[1024];
	// jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	int i = 1;
	for (int k = 0; k < jsonArray.Length; k++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(k));
		jsonObject.GetString("steamid", szSteamID, sizeof(szSteamID));
		jsonObject.GetString("name", szName, sizeof(szName));
		jsonObject.GetString("mapname", szMap, sizeof(szMap));
		time = jsonObject.GetFloat("overall");

		if (i == 1 || (i > 1 && StrEqual(szFirstMap, szMap)))
		{
			if (i < 51)
			{
				char szTime[32];
				FormatTimeFloat(client, time, 3, szTime, sizeof(szTime));
				if (time < 3600.0)
					Format(szTime, 32, "   %s", szTime);
				if (i == 100)
					Format(szValue, sizeof(szValue), "[%i.] %s |    » %s", i, szTime, szName);
				if (i >= 10)
					Format(szValue, sizeof(szValue), "[%i.] %s |    » %s", i, szTime, szName);
				else
					Format(szValue, sizeof(szValue), "[0%i.] %s |    » %s", i, szTime, szName);
				topMenu.AddItem(szSteamID, szValue, ITEMDRAW_DEFAULT);
				if (i == 1)
					Format(szFirstMap, sizeof(szFirstMap), "%s", szMap);
				i++;
			}
		}
		delete jsonObject
	}
	if (i == 1)
	{
		CPrintToChat(client, "%t", "NoTopRecords", g_szChatPrefix, szMap);
	}
	else
	{
		Format(title, sizeof(title), "Top 50 Times on %s (B %i) \n    Rank    Time               Player", szFirstMap, zGrp);
		topMenu.SetTitle(title);
		topMenu.OptionFlags = MENUFLAG_BUTTON_EXIT;
		topMenu.Display(client, MENU_TIME_FOREVER);
	}

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

public void apiSelectPlayerSpecificBonusDataCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NoContent)
		{
			CPrintToChat(client, "%t", "SQL28", g_szChatPrefix);
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	JSONObject jsonObject = view_as<JSONObject>(response.Data);

	char	   szSteamId[32], playername[MAX_NAME_LENGTH], mapname[128], apiRoute[512];
	jsonObject.GetString("steamid", szSteamId, sizeof(szSteamId));
	jsonObject.GetString("name", playername, sizeof(playername));
	jsonObject.GetString("mapname", mapname, sizeof(mapname));
	float runtimepro = jsonObject.GetFloat("runtime");
	int	  bonus		 = jsonObject.GetInt("zonegroup");

	FormatTimeFloat(client, runtimepro, 3, g_szRuntimepro[client], sizeof(g_szRuntimepro));

	DataPack dp = new DataPack();
	dp.WriteString("db_SelectTotalBonusCompletesCallback-cb-nested");
	dp.WriteFloat(GetGameTime());
	dp.WriteCell(client);
	dp.WriteString(szSteamId);
	dp.WriteString(playername);
	dp.WriteString(mapname);
	dp.WriteCell(bonus);
	dp.Reset();

	FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/selectTotalBonusCompletes?mapname=%s&zonegroup=%i", g_szApiHost, mapname, bonus);
	PrintToServer("API LINK: %s", apiRoute);
	/* RipExt - GET */
	HTTPRequest request = new HTTPRequest(apiRoute);
	request.Get(apiSelectTotalBonusCompletesCallback, dp);

	delete jsonObject;

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectTotalBonusCompletesCallback(HTTPResponse response, DataPack data)
{
	char func[128], szSteamId[32], playername[MAX_NAME_LENGTH], mapname[128], apiRoute[512];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	data.ReadString(szSteamId, sizeof(szSteamId));
	data.ReadString(playername, sizeof(playername));
	data.ReadString(mapname, sizeof(mapname));
	int bonus = data.ReadCell();

	if (response.Status != HTTPStatus_OK)
	{
		delete data;
		if (response.Status == HTTPStatus_NoContent)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	JSONObject jsonObject	   = view_as<JSONObject>(response.Data);
	g_totalPlayerTimes[client] = jsonObject.GetInt("count(name)");
	delete jsonObject;

	DataPack dp = new DataPack();
	dp.WriteString("db_SelectPlayersBonusRankCallback-cb-nested");
	dp.WriteFloat(GetGameTime());
	dp.WriteCell(client);
	dp.WriteString(szSteamId);
	dp.WriteString(playername);
	dp.WriteString(mapname);
	dp.WriteCell(bonus);
	dp.Reset();

	FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/selectPlayersBonusRank?steamid32=%s&mapname=%s&zonegroup=%i", g_szApiHost, szSteamId, mapname, bonus);
	PrintToServer("API LINK: %s", apiRoute);
	/* RipExt - GET */
	HTTPRequest request = new HTTPRequest(apiRoute);
	request.Get(apiSelectPlayersBonusRankCallback, dp);

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);
}

public void apiSelectPlayersBonusRankCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024], szSteamId[32], playername[MAX_NAME_LENGTH], mapname[128];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	data.ReadString(szSteamId, sizeof(szSteamId));
	data.ReadString(playername, sizeof(playername));
	data.ReadString(mapname, sizeof(mapname));
	int bonus = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		// LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	int rank = jsonArray.Length;
	CPrintToChatAll("%t", "SQL36", g_szChatPrefix, playername, rank, g_totalPlayerTimes[client], g_szRuntimepro[client], bonus, mapname);

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

/* ck_playeroptions2 */
public void apiSelectPlayerOptionsCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float time	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	if (!IsValidClient(client))
		return;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bSettingsLoaded[client])
			LoadClientSetting(client, g_iSettingToLoad[client]);

		if (response.Status == HTTPStatus_NotFound)
		{
			// "INSERT INTO ck_playeroptions2 (steamid, timer, hide, sounds, chat, viewmodel, autobhop, checkpoints, centrehud, module1c, module2c, module3c, module4c, module5c, module6c, sidehud, module1s, module2s, module3s, module4s, module5s) VALUES('%s', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i');";
			char apiRoute[512];
			FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/insertPlayerOptions?steamid32=%s", g_szApiHost, g_szSteamID[client]);

			// Prepare API call body
			JSONObject jsonObject = JSONObject.FromString("{}");

			DataPack   dp		  = new DataPack();
			dp.WriteString("sql_insertPlayerOptions-cb-nested");	// Actual new player I believe :thonk:
			dp.WriteFloat(GetGameTime());
			dp.Reset();

			PrintToServer("API ROUTE: %s", apiRoute);
			/* RipExt */
			HTTPRequest request = new HTTPRequest(apiRoute);
			request.Post(jsonObject, apiPostCallback, dp);

			g_bTimerEnabled[client]		  = true;
			g_bHide[client]				  = false;
			g_bEnableQuakeSounds[client]  = true;
			g_bHideChat[client]			  = false;
			g_bViewModel[client]		  = true;
			g_bAutoBhopClient[client]	  = true;
			g_bCheckpointsEnabled[client] = true;
			g_SpeedGradient[client]		  = 3;
			g_SpeedMode[client]			  = 0;
			g_bCenterSpeedDisplay[client] = false;
			g_bCentreHud[client]		  = true;
			g_iTeleSide[client]			  = 0;
			g_iCentreHudModule[client][0] = 1;
			g_iCentreHudModule[client][1] = 2;
			g_iCentreHudModule[client][2] = 3;
			g_iCentreHudModule[client][3] = 4;
			g_iCentreHudModule[client][4] = 5;
			g_iCentreHudModule[client][5] = 6;
			g_bSideHud[client]			  = true;
			g_iSideHudModule[client][0]	  = 5;
			g_iSideHudModule[client][1]	  = 0;
			g_iSideHudModule[client][2]	  = 0;
			g_iSideHudModule[client][3]	  = 0;
			g_iSideHudModule[client][4]	  = 0;
			g_bSpecListOnly[client]		  = true;
			g_iPrespeedText[client]		  = false;
			g_iCpMessages[client]		  = false;
			g_iWrcpMessages[client]		  = false;
			g_bAllowHints[client]		  = true;
			g_iCSDUpdateRate[client]	  = 1;
			g_fCSD_POS_X[client]		  = 0.5;
			g_fCSD_POS_Y[client]		  = 0.4;
			g_iCSD_R[client]			  = 255;
			g_iCSD_G[client]			  = 255;
			g_iCSD_B[client]			  = 255;
			g_PreSpeedMode[client]		  = 0;
			return;
		}
		LogError("[Surf API] API Error (%s)", func);

		return;
	}

	JSONObject jsonObject		  = view_as<JSONObject>(response.Data);
	// char out[1024];
	// jsonObject.ToString(out, sizeof(out));
	// PrintToServer("[Surf API] Output (%s): %s", func, out);

	// "SELECT timer, hide, sounds, chat, viewmodel, autobhop, checkpoints, gradient, speedmode, centrehud, module1c, module2c, module3c, module4c, module5c, module6c, sidehud, module1s, module2s, module3s, module4s, module5s, prestrafe FROM ck_playeroptions2 where steamid = '%s';"

	g_bTimerEnabled[client]		  = view_as<bool>(jsonObject.GetInt("timer"));
	g_bHide[client]				  = view_as<bool>(jsonObject.GetInt("hide"));
	g_bEnableQuakeSounds[client]  = view_as<bool>(jsonObject.GetInt("sounds"));
	g_bHideChat[client]			  = view_as<bool>(jsonObject.GetInt("chat"));
	g_bViewModel[client]		  = view_as<bool>(jsonObject.GetInt("viewmodel"));
	g_bAutoBhopClient[client]	  = view_as<bool>(jsonObject.GetInt("autobhop"));
	g_bCheckpointsEnabled[client] = view_as<bool>(jsonObject.GetInt("checkpoints"));
	g_SpeedGradient[client]		  = jsonObject.GetInt("gradient");
	g_SpeedMode[client]			  = jsonObject.GetInt("speedmode");
	g_bCenterSpeedDisplay[client] = view_as<bool>(jsonObject.GetInt("centrespeed"));
	g_bCentreHud[client]		  = view_as<bool>(jsonObject.GetInt("centrehud"));
	g_iTeleSide[client]			  = jsonObject.GetInt("teleside");
	g_iCentreHudModule[client][0] = jsonObject.GetInt("module1c");
	g_iCentreHudModule[client][1] = jsonObject.GetInt("module2c");
	g_iCentreHudModule[client][2] = jsonObject.GetInt("module3c");
	g_iCentreHudModule[client][3] = jsonObject.GetInt("module4c");
	g_iCentreHudModule[client][4] = jsonObject.GetInt("module5c");
	g_iCentreHudModule[client][5] = jsonObject.GetInt("module6c");
	g_bSideHud[client]			  = view_as<bool>(jsonObject.GetInt("sidehud"));
	g_iSideHudModule[client][0]	  = jsonObject.GetInt("module1s");
	g_iSideHudModule[client][1]	  = jsonObject.GetInt("module2s");
	g_iSideHudModule[client][2]	  = jsonObject.GetInt("module3s");
	g_iSideHudModule[client][3]	  = jsonObject.GetInt("module4s");
	g_iSideHudModule[client][4]	  = jsonObject.GetInt("module5s");
	g_iPrespeedText[client]		  = view_as<bool>(jsonObject.GetInt("prestrafe"));
	g_iCpMessages[client]		  = view_as<bool>(jsonObject.GetInt("cpmessages"));
	g_iWrcpMessages[client]		  = view_as<bool>(jsonObject.GetInt("wrcpmessages"));
	g_bAllowHints[client]		  = view_as<bool>(jsonObject.GetInt("hints"));
	g_iCSDUpdateRate[client]	  = jsonObject.GetInt("csd_update_rate");
	g_fCSD_POS_X[client]		  = jsonObject.GetFloat("csd_pos_x");
	g_fCSD_POS_Y[client]		  = jsonObject.GetFloat("csd_pos_y");
	g_iCSD_R[client]			  = jsonObject.GetInt("csd_r");
	g_iCSD_G[client]			  = jsonObject.GetInt("csd_g");
	g_iCSD_B[client]			  = jsonObject.GetInt("csd_b");
	g_PreSpeedMode[client]		  = jsonObject.GetInt("prespeedmode");

	// Functionality for normal spec list
	if (g_iSideHudModule[client][0] == 5 && (g_iSideHudModule[client][1] == 0 && g_iSideHudModule[client][2] == 0 && g_iSideHudModule[client][3] == 0 && g_iSideHudModule[client][4] == 0))
		g_bSpecListOnly[client] = true;
	else
		g_bSpecListOnly[client] = false;

	g_bLoadedModules[client] = true;

	if (!g_bSettingsLoaded[client])
	{
		LoadClientSetting(client, g_iSettingToLoad[client]);
	}

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
	delete jsonObject;
}

public void apiSelectPlayerNameCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float time	   = data.ReadFloat();
	int	  clientid = data.ReadCell();
	int	  client   = data.ReadCell();
	delete data;

	if (!IsValidClient(client))
		return;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			PrintToConsole(client, "SteamID %s not found.", g_pr_szSteamID[clientid]);
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);

		return;
	}

	JSONObject jsonObject = view_as<JSONObject>(response.Data);
	// char	   out[1024];
	// jsonObject.ToString(out, sizeof(out));
	// PrintToServer("[Surf API] Output (%s): %s", func, out);

	jsonObject.GetString("name", g_pr_szName[clientid], sizeof(g_pr_szName));
	g_bProfileRecalc[clientid] = true;
	PrintToConsole(client, "Profile refreshed (%s).", g_pr_szSteamID[clientid]);

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
	delete jsonObject;
}

/* ck_playerrank */
public void apiSelectTop100PlayersCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  style	 = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		// LogError("[Surf API] API Returned empty array (%s)", func);
		CPrintToChat(client, "%t", "NoPlayerTop", g_szChatPrefix);
		delete jsonArray;
		return;
	}

	char szValue[128], szName[64], szRank[16], szSteamID[32], szPerc[16], szTitle[256];
	Menu menu = new Menu(TopPlayersMenuHandler1);
	if (style == 0)
		Format(szTitle, sizeof(szTitle), "Top 100 Players\n    Rank   Points       Maps            Player");
	else
		Format(szTitle, sizeof(szTitle), "Top 100 Players - %s\n    Rank   Points       Maps            Player", g_szStyleMenuPrint[style]);

	menu.SetTitle(szTitle);
	menu.Pagination = 5;

	jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	int i = 1;
	for (int k = 0; k < jsonArray.Length; k++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(k));
		jsonObject.GetString("name", szName, sizeof(szName));
		int points = jsonObject.GetInt("zonegroup");
		int pro	   = jsonObject.GetInt("finishedmapspro");
		jsonObject.GetString("steamid", szSteamID, sizeof(szSteamID));

		if (i == 100)
			Format(szRank, 16, "[%i.]", i);
		else if (i < 10)
			Format(szRank, 16, "[0%i.]  ", i);
		else
			Format(szRank, 16, "[%i.]  ", i);

		float fperc;
		fperc = (float(pro) / (float(g_pr_MapCount[0]))) * 100.0;

		if (fperc < 10.0)
			Format(szPerc, 16, "  %.1f%c  ", fperc, PERCENT);
		else if (fperc == 100.0)
			Format(szPerc, 16, "100.0%c", PERCENT);
		else if (fperc > 100.0)	   // player profile not refreshed after removing maps
			Format(szPerc, 16, "100.0%c", PERCENT);
		else
			Format(szPerc, 16, "%.1f%c  ", fperc, PERCENT);

		if (points < 10)
			Format(szValue, 128, "%s      %ip       %s     » %s", szRank, points, szPerc, szName);
		else if (points < 100)
			Format(szValue, 128, "%s     %ip       %s     » %s", szRank, points, szPerc, szName);
		else if (points < 1000)
			Format(szValue, 128, "%s   %ip       %s     » %s", szRank, points, szPerc, szName);
		else if (points < 10000)
			Format(szValue, 128, "%s %ip       %s     » %s", szRank, points, szPerc, szName);
		else if (points < 100000)
			Format(szValue, 128, "%s %ip     %s     » %s", szRank, points, szPerc, szName);
		else
			Format(szValue, 128, "%s %ip   %s     » %s", szRank, points, szPerc, szName);

		menu.AddItem(szSteamID, szValue, ITEMDRAW_DEFAULT);
		i++;

		delete jsonObject
	}
	if (i == 1)
	{
		CPrintToChat(client, "%t", "NoPlayerTop", g_szChatPrefix);
	}

	menu.OptionFlags = MENUFLAG_BUTTON_EXIT;
	menu.Display(client, MENU_TIME_FOREVER);

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

public void apiSelectRankedPlayersRankCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();

	if (StrEqual(func, "db_GetPlayerRank"))
	{
		int client = data.ReadCell();
		int style  = data.ReadCell();
		delete data;

		if (!IsValidClient(client))
			return;

		if (response.Status != HTTPStatus_OK)
		{
			if (!g_bSettingsLoaded[client])
				LoadClientSetting(client, g_iSettingToLoad[client]);

			if (response.Status == HTTPStatus_NotFound)
			{
				LogQueryTime("[Surf API] No entries found (%s)", func);
				return;
			}
			LogError("[Surf API] API Error %i (%s)", response.Status, func);
			return;
		}

		// Indicate that the response contains a JSON array
		JSONArray jsonArray = view_as<JSONArray>(response.Data);
		if (jsonArray.Length <= 0)
		{
			if (style == 0 && GetConVarInt(g_hPrestigeRank) > 0 && !g_bPrestigeCheck[client])
				KickClient(client, "You must be at least rank %i to join this server", GetConVarInt(g_hPrestigeRank));

			delete jsonArray;
			return;
		}

		jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
		// PrintToServer("%s: %s", func, out);

		g_PlayerRank[client][style] = jsonArray.Length;
		if (GetConVarInt(g_hPrestigeRank) > 0)
		{
			if (GetConVarBool(g_hPrestigeStyles) && !g_bPrestigeAvoid[client])
			{
				if (style == 0)
				{
					if (g_PlayerRank[client][0] >= GetConVarInt(g_hPrestigeRank) && !g_bPrestigeCheck[client])
						KickClient(client, "You must be at least rank %i to join this server", GetConVarInt(g_hPrestigeRank));
				}

				if (style == MAX_STYLES && !g_bPrestigeCheck[client])
					KickClient(client, "You must be at least rank %i to join this server", GetConVarInt(g_hPrestigeRank));
			}
			else
			{
				if (g_PlayerRank[client][0] <= GetConVarInt(g_hPrestigeRank) || g_bPrestigeCheck[client])
					g_bPrestigeCheck[client] = true;
				else if (!g_bPrestigeAvoid[client])
					KickClient(client, "You must be at least rank %i to join this server", GetConVarInt(g_hPrestigeRank));
			}
		}

		// Custom Title Access
		if (g_PlayerRank[client][0] <= 3 && g_PlayerRank[client][0] > 0)	// Rank 1-3
			g_bCustomTitleAccess[client] = true;

		// Sort players by rank in scoreboard
		if (style == 0)
		{
			if (g_pr_AllPlayers[style] < g_PlayerRank[client][style] || g_PlayerRank[client][style] == 0)
				CS_SetClientContributionScore(client, -99999);
			else
				CS_SetClientContributionScore(client, -g_PlayerRank[client][style]);
		}

		delete jsonArray;
	}
	else if (StrEqual(func, "db_viewPlayerProfile") || StrEqual(func, "db_viewPlayerProfile-unknownPlayer"))
	{
		int	 client = data.ReadCell();
		int	 style	= data.ReadCell();
		char szSteamId[32], szName[MAX_NAME_LENGTH];
		data.ReadString(szSteamId, sizeof(szSteamId));
		data.ReadString(szName, sizeof(szName));

		if (response.Status != HTTPStatus_OK)
		{
			if (response.Status == HTTPStatus_NotFound)
			{
				LogQueryTime("[Surf API] No entries found (%s)", func);
				return;
			}
			LogError("[Surf API] API Error %i (%s)", response.Status, func);
			return;
		}

		// Indicate that the response contains a JSON array
		JSONArray jsonArray = view_as<JSONArray>(response.Data);
		if (jsonArray.Length <= 0)
		{
			CPrintToChat(client, "%t", "SQL40", g_szChatPrefix, szName);
			delete jsonArray;
			return;
		}

		char apiRoute[512];
		FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/selectPlayerProfile?steamid32=%s&style=%i", g_szApiHost, szSteamId, style);

		DataPack dp = new DataPack();
		dp.WriteString("selectPlayerProfile-cb-nested");
		dp.WriteFloat(GetGameTime());
		dp.WriteCell(client);
		dp.WriteCell(style);
		dp.WriteString(szSteamId);
		dp.WriteString(szName);
		dp.WriteCell(jsonArray.Length);
		dp.Reset();

		PrintToServer("API ROUTE: %s", apiRoute);

		/* RipExt */
		HTTPRequest request = new HTTPRequest(apiRoute);
		request.Get(apiSelectPlayerProfileCallback, dp);

		delete jsonArray;
	}
	else if (StrEqual(func, "db_selectPlayerRankUnknown"))
	{
		int client = data.ReadCell();
		delete data;

		if (response.Status != HTTPStatus_OK)
		{
			if (response.Status == HTTPStatus_NotFound)
			{
				CPrintToChat(client, "%t", "SQLTwo7", g_szChatPrefix);
				LogQueryTime("[Surf API] No entries found (%s)", func);
				return;
			}
			LogError("[Surf API] API Error %i (%s)", response.Status, func);
			return;
		}

		char	   szSteamId[32], szName[128], apiRoute[512];
		JSONObject jsonObject = view_as<JSONObject>(response.Data);
		jsonObject.GetString("steamid", szSteamId, sizeof(szSteamId));
		jsonObject.GetString("name", szName, sizeof(szName));
		int points = jsonObject.GetInt("points");
		delete jsonObject;

		DataPack dp = new DataPack();
		dp.WriteString("selectRankedPlayersRank-cb-nested from unknown");
		dp.WriteFloat(GetGameTime());
		dp.WriteString(szSteamId);
		dp.WriteString(szName);
		dp.WriteCell(points);
		dp.WriteCell(client);
		dp.Reset();

		FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/selectRankedPlayersRank?style=%i&steamid32=%s", g_szApiHost, 0, szSteamId);
		PrintToServer("API LINK: %s", apiRoute);
		/* RipExt - GET */
		HTTPRequest request = new HTTPRequest(apiRoute);
		request.Get(apiSelectRankedPlayersRankCallback, dp);
	}
	else if (StrEqual(func, "selectRankedPlayersRank-cb-nested from unknown"))
	{
		char szSteamId[32], szName[128];
		data.ReadString(szSteamId, sizeof(szSteamId));
		data.ReadString(szName, sizeof(szName));
		int points = data.ReadCell();
		int client = data.ReadCell();
		delete data;

		if (response.Status != HTTPStatus_OK)
		{
			if (response.Status == HTTPStatus_NotFound)
			{
				LogQueryTime("[Surf API] No entries found (%s)", func);
				return;
			}
			LogError("[Surf API] API Error %i (%s)", response.Status, func);
			return;
		}
		// Indicate that the response contains a JSON array
		JSONArray jsonArray = view_as<JSONArray>(response.Data);
		if (jsonArray.Length <= 0)
		{
			CPrintToChat(client, "%t", "SQL40", g_szChatPrefix, szName);
			delete jsonArray;
			delete data;
			return;
		}

		int playerrank = jsonArray.Length;
		CPrintToChatAll("%t", "SQL39", g_szChatPrefix, szName, playerrank, g_pr_RankedPlayers, points);
		delete jsonArray;
	}

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

public void apiSelectPlayerProfileCallback(HTTPResponse response, DataPack data)
{
	char func[128], out[1024];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  style	 = data.ReadCell();
	char  szSteamId[32], szName2[MAX_NAME_LENGTH];
	data.ReadString(szSteamId, sizeof(szSteamId));
	data.ReadString(szName2, sizeof(szName2));
	int rank = data.ReadCell();

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	JSONObject jsonObject = view_as<JSONObject>(response.Data);
	jsonObject.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	char szName[MAX_NAME_LENGTH], szSteamId2[32], szCountry[64];

	jsonObject.GetString("steamid", szSteamId2, sizeof(szSteamId2));
	Format(g_szProfileSteamId[client], sizeof(g_szProfileSteamId), szSteamId2);
	jsonObject.GetString("name", szName, sizeof(szName));
	Format(g_szProfileName[client], sizeof(g_szProfileName), szName);
	jsonObject.GetString("country", szCountry, sizeof(szCountry));
	int points			= jsonObject.GetInt("points");
	int wrPoints		= jsonObject.GetInt("wrpoints");
	int wrbPoints		= jsonObject.GetInt("wrbpoints");
	int wrcpPoints		= jsonObject.GetInt("wrcppoints");
	int top10Points		= jsonObject.GetInt("top10points");
	int groupPoints		= jsonObject.GetInt("groupspoints");
	int mapPoints		= jsonObject.GetInt("mappoints");
	int bonusPoints		= jsonObject.GetInt("bonuspoints");
	int finishedMaps	= jsonObject.GetInt("finishedmapspro");
	int finishedBonuses = jsonObject.GetInt("finishedbonuses");
	int finishedStages	= jsonObject.GetInt("finishedstages");
	int wrs				= jsonObject.GetInt("wrs");
	int wrbs			= jsonObject.GetInt("wrbs");
	int wrcps			= jsonObject.GetInt("wrcps");
	int top10s			= jsonObject.GetInt("top10s");
	int groups			= jsonObject.GetInt("groups");
	int lastseen		= jsonObject.GetInt("lastseen");

	if (finishedMaps > g_pr_MapCount[0])
		finishedMaps = g_pr_MapCount[0];

	if (finishedBonuses > g_pr_BonusCount)
		finishedBonuses = g_pr_BonusCount;

	if (finishedStages > g_pr_StageCount)
		finishedStages = g_pr_StageCount;

	int	  totalCompleted = finishedMaps + finishedBonuses + finishedStages;
	int	  totalZones	 = g_pr_MapCount[0] + g_pr_BonusCount + g_pr_StageCount;

	// Completion Percentage
	float fPerc, fBPerc, fSPerc, fTotalPerc;
	char  szPerc[32], szBPerc[32], szSPerc[32], szTotalPerc[32];

	// Calculate percentages and format them into strings
	fPerc	   = (float(finishedMaps) / (float(g_pr_MapCount[0]))) * 100.0;
	fBPerc	   = (float(finishedBonuses) / (float(g_pr_BonusCount))) * 100.0;
	fSPerc	   = (float(finishedStages) / (float(g_pr_StageCount))) * 100.0;
	fTotalPerc = (float(totalCompleted) / (float(totalZones))) * 100.0;

	FormatPercentage(fPerc, szPerc, sizeof(szPerc));
	FormatPercentage(fBPerc, szBPerc, sizeof(szBPerc));
	FormatPercentage(fSPerc, szSPerc, sizeof(szSPerc));
	FormatPercentage(fTotalPerc, szTotalPerc, sizeof(szTotalPerc));

	// Get players skillgroup
	SkillGroup RankValue;
	int		   index = GetSkillgroupIndex(rank, points);
	GetArrayArray(g_hSkillGroups, index, RankValue, sizeof(SkillGroup));
	char szSkillGroup[128];
	Format(szSkillGroup, sizeof(szSkillGroup), RankValue.RankName);
	ReplaceString(szSkillGroup, sizeof(szSkillGroup), "{style}", "");

	char szRank[32];
	if (rank > g_pr_RankedPlayers[0] || points == 0)
		Format(szRank, 32, "-");
	else
		Format(szRank, 32, "%i", rank);

	// Format Profile Menu
	char szCompleted[1024], szMapPoints[128], szBonusPoints[128], szTop10Points[128], szStagePc[128], szMiPc[128], szRecords[128], szLastSeen[128];

	// Get last seen
	int	 time = GetTime();
	int	 unix = time - lastseen;
	diffForHumans(unix, szLastSeen, sizeof(szLastSeen), 1);

	Format(szMapPoints, 128, "Maps: %i/%i - [%i] (%s%c)", finishedMaps, g_pr_MapCount[0], mapPoints, szPerc, PERCENT);

	if (wrbPoints > 0)
		Format(szBonusPoints, 128, "Bonuses: %i/%i - [%i+%i] (%s%c)", finishedBonuses, g_pr_BonusCount, bonusPoints, wrbPoints, szBPerc, PERCENT);
	else
		Format(szBonusPoints, 128, "Bonuses: %i/%i - [%i] (%s%c)", finishedBonuses, g_pr_BonusCount, bonusPoints, szBPerc, PERCENT);

	if (wrPoints > 0)
		Format(szTop10Points, 128, "Top10: %i - [%i+%i]", top10s, top10Points, wrPoints);
	else
		Format(szTop10Points, 128, "Top10: %i - [%i]", top10s, top10Points);

	if (wrcpPoints > 0)
		Format(szStagePc, 128, "Stages: %i/%i [0+%d] (%s%c)", finishedStages, g_pr_StageCount, wrcpPoints, szSPerc, PERCENT);
	else
		Format(szStagePc, 128, "Stages: %i/%i [0] (%s%c)", finishedStages, g_pr_StageCount, szSPerc, PERCENT);

	Format(szMiPc, 128, "Map Improvement Pts: %i - [%i]", groups, groupPoints);

	Format(szRecords, 128, "Records:\nMap WR: %i\nStage WR: %i\nBonus WR: %i", wrs, wrcps, wrbs);

	Format(szCompleted, 1024, "Completed - Points (%s%c):\n%s\n%s\n%s\n%s\n \n%s\n \n%s\n \n", szTotalPerc, PERCENT, szMapPoints, szBonusPoints, szTop10Points, szStagePc, szMiPc, szRecords);

	Format(g_pr_szrank[client], 512, "Rank: %s/%i %s\nTotal pts: %i\n \n", szRank, g_pr_RankedPlayers[style], szSkillGroup, points);

	char szTop[128];
	if (style > 0)
		Format(szTop, sizeof(szTop), "[%s | %s | Online: %s]\n", szName, g_szStyleMenuPrint[style], szLastSeen);
	else
		Format(szTop, sizeof(szTop), "[%s ||| Online: %s]\n", szName, szLastSeen);

	char szTitle[1024];
	if (GetConVarBool(g_hCountry))
		Format(szTitle, 1024, "%s-------------------------------------\n%s\nCountry: %s\n \n%s\n", szTop, szSteamId, szCountry, g_pr_szrank[client]);
	else
		Format(szTitle, 1024, "%s-------------------------------------\n%s\n \n%s", szTop, szSteamId, g_pr_szrank[client]);

	Menu menu = CreateMenu(ProfileMenuHandler);
	SetMenuTitle(menu, szTitle);
	AddMenuItem(menu, "Finished maps", szCompleted);
	AddMenuItem(menu, szSteamId, "Player Info");

	if (IsValidClient(client))
		if (StrEqual(szSteamId, g_szSteamID[client]))
			AddMenuItem(menu, "Refresh my profile", "Refresh my profile");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	delete jsonObject;
	delete data;
}

public void apiSelectRankedPlayersCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime		 = data.ReadFloat();
	int	  passedData = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogQueryTime("[Surf API] API Returned empty array (%s)", func);
		PrintToConsole(g_pr_Recalc_AdminID, " \n>> No valid players found!");
		delete jsonArray;
		return;
	}

	// char out[1024];
	// jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);

	int i = 66;
	int x;
	g_pr_TableRowCount = jsonArray.Length;
	if (g_pr_TableRowCount == 0)
	{
		for (int c = 1; c <= MaxClients; c++)
			if (1 <= c <= MaxClients && IsValidEntity(c) && IsValidClient(c))
			{
				if (g_bManualRecalc)
					CPrintToChat(c, "%t", "PrUpdateFinished", g_szChatPrefix);
			}

		g_bManualRecalc				  = false;
		g_pr_RankingRecalc_InProgress = false;

		if (IsValidClient(g_pr_Recalc_AdminID))
		{
			PrintToConsole(g_pr_Recalc_AdminID, ">> Recalculation finished");
			CreateTimer(0.1, RefreshAdminMenu, g_pr_Recalc_AdminID, TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	if (MAX_PR_PLAYERS != passedData && g_pr_TableRowCount > passedData)
		x = 66 + passedData;
	else
		x = 66 + g_pr_TableRowCount;

	if (g_pr_TableRowCount > MAX_PR_PLAYERS)
		g_pr_TableRowCount = MAX_PR_PLAYERS;

	if (x > MAX_PR_PLAYERS)
		x = MAX_PR_PLAYERS - 1;

	if (IsValidClient(g_pr_Recalc_AdminID) && g_bManualRecalc)
	{
		int max = MAX_PR_PLAYERS - 66;
		PrintToConsole(g_pr_Recalc_AdminID, " \n>> Recalculation started! (Only Top %i because of performance reasons)", max);
	}

	for (int k = 0; k < jsonArray.Length; k++)
	{
		JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(k));
		if (i <= x)
		{
			g_pr_points[i][0] = 0;
			jsonObject.GetString("steamid", g_pr_szSteamID[i], sizeof(g_pr_szSteamID));
			jsonObject.GetString("name", g_pr_szName[i], sizeof(g_pr_szName));
			g_bProfileRecalc[i] = true;
			i++;
		}
		if (i == x)
		{
			CalculatePlayerRank(66, 0);
		}
		delete jsonObject
	}

	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

public void apiSelectCountPlayersCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime = data.ReadFloat();
	int	  style = data.ReadCell();
	delete data;

	if (StrEqual(func, "db_CalculatePlayerCount"))
	{
		if (response.Status != HTTPStatus_OK)
		{
			db_CalculatePlayersCountGreater0(style);
			if (response.Status == HTTPStatus_NotFound)
			{
				g_pr_AllPlayers[style] = 1;
				LogQueryTime("[Surf API] No entries found (%s)", func);
				return;
			}
			LogError("[Surf API] API Error %i (%s)", response.Status, func);
			return;
		}

		g_pr_AllPlayers[style] = 1;
		JSONObject jsonObject  = view_as<JSONObject>(response.Data);
		g_pr_AllPlayers[style] = jsonObject.GetInt("COUNT(steamid)");

		// char out[1024];
		// jsonObject.ToString(out, sizeof(out), JSON_DECODE_ANY);
		// PrintToServer("%s: %s", func, out);

		db_CalculatePlayersCountGreater0(style);
		delete jsonObject;
	}
	else if (StrEqual(func, "db_CalculatePlayersCountGreater0"))
	{
		if (response.Status != HTTPStatus_OK)
		{
			if (!g_bServerDataLoaded)
				db_selectSpawnLocations();

			if (response.Status == HTTPStatus_NotFound)
			{
				g_pr_AllPlayers[style] = 1;
				LogQueryTime("[Surf API] No entries found (%s)", func);
				return;
			}
			LogError("[Surf API] API Error %i (%s)", response.Status, func);
			return;
		}

		g_pr_RankedPlayers[style] = 0;
		JSONObject jsonObject	  = view_as<JSONObject>(response.Data);
		g_pr_RankedPlayers[style] = jsonObject.GetInt("COUNT(steamid)");

		if (!g_bServerDataLoaded)
			db_selectSpawnLocations();

		delete jsonObject;
	}

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

public void apiSelectPlayerPointsCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float fTime	 = data.ReadFloat();
	int	  client = data.ReadCell();
	delete data;

	if (response.Status != HTTPStatus_OK)
	{
		if (!g_bSettingsLoaded[client])
			LoadClientSetting(client, g_iSettingToLoad[client]);

		if (response.Status == HTTPStatus_NotFound)
		{
			LogQueryTime("[Surf API] No entries found (%s)", func);
			return;
		}
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length <= 0)
	{
		// Array is empty stop here
		LogError("[Surf API] API Returned empty array (%s)", func);
		delete jsonArray;
		return;
	}

	// char out[1024];
	// jsonArray.ToString(out, sizeof(out), JSON_DECODE_ANY);
	// PrintToServer("%s: %s", func, out);
	int style;

	for (int k = 0; k < jsonArray.Length; k++)
	{
		JSONObject jsonObject				  = view_as<JSONObject>(jsonArray.Get(k));
		style								  = jsonObject.GetInt("style");
		g_pr_points[client][style]			  = jsonObject.GetInt("points");
		g_pr_finishedmaps[client][style]	  = jsonObject.GetInt("finishedmapspro");
		g_pr_finishedmaps_perc[client][style] = (float(g_pr_finishedmaps[client][style]) / float(g_pr_MapCount[0])) * 100.0;

		if (style == 0)
		{
			g_iPlayTimeAlive[client]	= jsonObject.GetInt("timealive");
			g_iPlayTimeSpec[client]		= jsonObject.GetInt("timespec");
			g_iTotalConnections[client] = jsonObject.GetInt("connections");
		}

		delete jsonObject
	}

	g_iTotalConnections[client]++;

	// Prepare API call body
	JSONObject jsonObject;
	jsonObject	= JSONObject.FromString("{}");

	DataPack dp = new DataPack();
	dp.WriteString("updateConnections");
	dp.WriteFloat(GetGameTime());
	dp.Reset();

	char apiRoute[512];
	FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/updatePlayerConnections?steamid32=%s", g_szApiHost, g_szSteamID[client]);
	/* RipExt - PUT */
	HTTPRequest request = new HTTPRequest(apiRoute);
	request.Put(jsonObject, apiPutCallback, dp);

	// Count players rank
	if (IsValidClient(client))
		for (int i = 0; i < MAX_STYLES; i++)
			db_GetPlayerRank(client, i);

	delete jsonObject;
	delete jsonArray;
	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - fTime);

	return;
}

/* Player Points Calculation */
public void apiCalculatePlayerPointsCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float time	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  style	 = data.ReadCell();
	delete data;
	char szSteamId[32], szSteamId64[64];

	getSteamIDFromClient(client, szSteamId, sizeof(szSteamId));

	if (IsValidClient(client))
	{
		GetClientAuthId(client, AuthId_SteamID64, szSteamId64, MAX_NAME_LENGTH, true);
	}

	// PrintToServer("client: %i | SteamID32: %s | SteamID64: %s", client, szSteamId, szSteamId64);

	if (response.Status == HTTPStatus_NotFound)
	{
		LogQueryTime("[Surf API] No entries found (%s)", func);
		// Players first time on server
		if (client <= MaxClients)
		{
			g_pr_Calculating[client] = false;
			g_pr_AllPlayers[style]++;

			// Insert player to database
			char szUName[MAX_NAME_LENGTH];
			char szName[MAX_NAME_LENGTH * 2 + 1];

			GetClientName(client, szUName, MAX_NAME_LENGTH);
			SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);

			// "INSERT INTO ck_playerrank (steamid, name, country) VALUES('%s', '%s', '%s');";
			// No need to continue calculating, as the doesn't have any records.
			char apiRoute[512], body[1024];

			// Prepare API call body
			FormatEx(body, sizeof(body), api_insertPlayerRank, szSteamId, szSteamId64, szName, g_szCountry[client], g_szCountryCode[client], g_szContinentCode[client], GetTime(), style);
			JSONObject jsonObject;
			jsonObject	= JSONObject.FromString(body);

			DataPack dp = new DataPack();
			dp.WriteString("CalculatePlayerRank-2nd-NewPlayer");
			dp.WriteFloat(GetGameTime());
			dp.WriteCell(client);
			dp.Reset();

			FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/insertPlayerRank", g_szApiHost);
			PrintToServer("API LINK: %s", apiRoute);
			PrintToServer("API BODY: %s", body);

			/* RipExt - POST */
			HTTPRequest request = new HTTPRequest(apiRoute);
			request.Post(jsonObject, apiPostCallback, dp);

			delete jsonObject;

			g_pr_finishedmaps[client][style]	  = 0;
			g_pr_finishedmaps_perc[client][style] = 0.0;
			g_pr_finishedbonuses[client][style]	  = 0;
			g_pr_finishedstages[client][style]	  = 0;
			g_GroupMaps[client][style]			  = 0;	  // Group Maps
			g_Top10Maps[client][style]			  = 0;	  // Top 10 Maps

			// play time
			g_iPlayTimeAlive[client]			  = 0;
			g_iPlayTimeSpec[client]				  = 0;

			CalculatePlayerRank(client, style);

			return;
		}
	}
	else if (response.Status != HTTPStatus_OK)
	{
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	JSONObject jsonObject = view_as<JSONObject>(response.Data);
	// char	   out[1024];
	// jsonObject.ToString(out, sizeof(out));
	// PrintToServer("[Surf API] Output (%s): %s", func, out);

	if (IsValidClient(client))
	{
		g_pr_Calculating[client] = true;
		if (GetClientTime(client) < (GetGameTime() - g_fMapStartTime))
		{
			db_UpdateLastSeen(client);	  // Update last seen on server
		}
	}

	char apiRoute[512];
	FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/point_calc_countFinishedBonus?steamid32=%s&style=%i", g_szApiHost, szSteamId, style);

	DataPack dp = new DataPack();
	dp.WriteString("CalculatePlayerRank-2nd-Bonuses");
	dp.WriteFloat(GetGameTime());
	dp.WriteCell(client);
	dp.WriteCell(style);
	dp.Reset();

	PrintToServer("API ROUTE: %s", apiRoute);

	/* RipExt */
	HTTPRequest request = new HTTPRequest(apiRoute);
	request.Get(apiCalculatePlayerPointsCountFinishedBonusCallback, dp);

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
	delete jsonObject;
}

public void apiCalculatePlayerPointsCountFinishedBonusCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float time	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  style	 = data.ReadCell();
	delete data;

	char szMap[128], szSteamId[32], szMapName2[128];

	getSteamIDFromClient(client, szSteamId, 32);
	int finishedbonuses = 0;
	int wrbs			= 0;

	if (response.Status == HTTPStatus_NoContent)
	{
		LogQueryTime("[Surf API] No entries found (%s)", func);
	}
	else if (response.Status != HTTPStatus_OK)
	{
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length > 0)
	{
		for (int i = 0; i < jsonArray.Length; i++)
		{
			finishedbonuses++;
			JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
			jsonObject.GetString("mapname", szMap, sizeof(szMap));
			int rank = jsonObject.GetInt("rank");

			for (int k = 0; k < GetArraySize(g_MapList); k++)	 // Check that the map is in the mapcycle
			{
				GetArrayString(g_MapList, k, szMapName2, sizeof(szMapName2));
				if (StrEqual(szMapName2, szMap, false))
				{
					switch (rank)
					{
						case 1:
						{
							g_pr_points[client][style] += 250;
							g_Points[client][style][4] += 250;
							wrbs++;
						}
						case 2:
						{
							g_pr_points[client][style] += 235;
							g_Points[client][style][1] += 235;
						}
						case 3:
						{
							g_pr_points[client][style] += 220;
							g_Points[client][style][1] += 220;
						}
						case 4:
						{
							g_pr_points[client][style] += 205;
							g_Points[client][style][1] += 205;
						}
						case 5:
						{
							g_pr_points[client][style] += 190;
							g_Points[client][style][1] += 190;
						}
						case 6:
						{
							g_pr_points[client][style] += 175;
							g_Points[client][style][1] += 175;
						}
						case 7:
						{
							g_pr_points[client][style] += 160;
							g_Points[client][style][1] += 160;
						}
						case 8:
						{
							g_pr_points[client][style] += 145;
							g_Points[client][style][1] += 145;
						}
						case 9:
						{
							g_pr_points[client][style] += 130;
							g_Points[client][style][1] += 130;
						}
						case 10:
						{
							g_pr_points[client][style] += 100;
							g_Points[client][style][1] += 100;
						}
						case 11:
						{
							g_pr_points[client][style] += 95;
							g_Points[client][style][1] += 95;
						}
						case 12:
						{
							g_pr_points[client][style] += 90;
							g_Points[client][style][1] += 90;
						}
						case 13:
						{
							g_pr_points[client][style] += 80;
							g_Points[client][style][1] += 80;
						}
						case 14:
						{
							g_pr_points[client][style] += 70;
							g_Points[client][style][1] += 70;
						}
						case 15:
						{
							g_pr_points[client][style] += 60;
							g_Points[client][style][1] += 60;
						}
						case 16:
						{
							g_pr_points[client][style] += 50;
							g_Points[client][style][1] += 50;
						}
						case 17:
						{
							g_pr_points[client][style] += 40;
							g_Points[client][style][1] += 40;
						}
						case 18:
						{
							g_pr_points[client][style] += 30;
							g_Points[client][style][1] += 30;
						}
						case 19:
						{
							g_pr_points[client][style] += 20;
							g_Points[client][style][1] += 20;
						}
						case 20:
						{
							g_pr_points[client][style] += 10;
							g_Points[client][style][1] += 10;
						}
						default:
						{
							g_pr_points[client][style] += 5;
							g_Points[client][style][1] += 5;
						}
					}
					break;
				}
			}
			delete jsonObject;
		}
		delete jsonArray;
	}

	g_pr_finishedbonuses[client][style] = finishedbonuses;
	g_WRs[client][style][1]				= wrbs;

	char apiRoute[512];
	FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/point_calc_finishedStages?steamid32=%s&style=%i", g_szApiHost, szSteamId, style);

	DataPack dp = new DataPack();
	dp.WriteString("CalculatePlayerRank-3rd-Stages");
	dp.WriteFloat(GetGameTime());
	dp.WriteCell(client);
	dp.WriteCell(style);
	dp.Reset();

	PrintToServer("API ROUTE: %s", apiRoute);

	/* RipExt */
	HTTPRequest request = new HTTPRequest(apiRoute);
	request.Get(apiCalculatePlayerPointsCountFinishedStagesCallback, dp);

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
}

public void apiCalculatePlayerPointsCountFinishedStagesCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float time	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  style	 = data.ReadCell();
	delete data;

	char szMap[128], szSteamId[32], szMapName2[128];

	getSteamIDFromClient(client, szSteamId, 32);
	int finishedstages = 0;
	int wrcps		   = 0;

	if (response.Status == HTTPStatus_NoContent)
	{
		LogQueryTime("[Surf API] No entries found (%s)", func);
	}
	else if (response.Status != HTTPStatus_OK)
	{
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length > 0)
	{
		for (int i = 0; i < jsonArray.Length; i++)
		{
			finishedstages++;
			JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
			jsonObject.GetString("mapname", szMap, sizeof(szMap));
			int rank = jsonObject.GetInt("rank");

			for (int k = 0; k < GetArraySize(g_MapList); k++)	 // Check that the map is in the mapcycle
			{
				GetArrayString(g_MapList, k, szMapName2, sizeof(szMapName2));
				if (StrEqual(szMapName2, szMap, false))
				{
					if (rank == 1)
					{
						wrcps++;
						int wrcpPoints = GetConVarInt(g_hWrcpPoints);
						if (wrcpPoints > 0)
						{
							g_pr_points[client][style] += wrcpPoints;
							g_Points[client][style][6] += wrcpPoints;
						}
					}
					break;
				}
			}
			delete jsonObject;
		}
	}
	delete jsonArray;

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
	g_pr_finishedstages[client][style] = finishedstages;
	g_WRs[client][style][2]			   = wrcps;

	char apiRoute[512];
	FormatEx(apiRoute, sizeof(apiRoute), "%s/surftimer/point_calc_finishedMaps?steamid32=%s&style=%i", g_szApiHost, szSteamId, style);

	DataPack dp = new DataPack();
	dp.WriteString("CalculatePlayerRank-4th-Maps");
	dp.WriteFloat(GetGameTime());
	dp.WriteCell(client);
	dp.WriteCell(style);
	dp.Reset();

	PrintToServer("API ROUTE: %s", apiRoute);

	/* RipExt */
	HTTPRequest request = new HTTPRequest(apiRoute);
	request.Get(apiCalculatePlayerPointsCountFinishedMapsCallback, dp);
}

public void apiCalculatePlayerPointsCountFinishedMapsCallback(HTTPResponse response, DataPack data)
{
	char func[128];
	data.ReadString(func, sizeof(func));
	float time	 = data.ReadFloat();
	int	  client = data.ReadCell();
	int	  style	 = data.ReadCell();
	delete data;

	char szMap[128], szMapName2[128];
	int	 finishedMaps = 0, wrs;

	if (response.Status == HTTPStatus_NoContent)
	{
		LogQueryTime("[Surf API] No entries found (%s)", func);
	}
	else if (response.Status != HTTPStatus_OK)
	{
		LogError("[Surf API] API Error %i (%s)", response.Status, func);
		return;
	}

	// Indicate that the response contains a JSON array
	JSONArray jsonArray = view_as<JSONArray>(response.Data);
	if (jsonArray.Length > 0)
	{
		for (int i = 0; i < jsonArray.Length; i++)
		{
			JSONObject jsonObject = view_as<JSONObject>(jsonArray.Get(i));
			jsonObject.GetString("mapname", szMap, sizeof(szMap));
			int totalplayers = jsonObject.GetInt("total");
			int rank		 = jsonObject.GetInt("rank");
			int tier		 = jsonObject.GetInt("tier");

			for (int k = 0; k < GetArraySize(g_MapList); k++)	 // Check that the map is in the mapcycle
			{
				GetArrayString(g_MapList, k, szMapName2, sizeof(szMapName2));
				if (StrEqual(szMapName2, szMap, false))
				{
					finishedMaps++;
					float wrpoints;
					int	  iwrpoints;
					float points;
					float g1points;
					float g2points;
					float g3points;
					float g4points;
					float g5points;

					// Calculate Group Ranks
					// Group 1
					float fG1top;
					int	  g1top;
					int	  g1bot = 11;
					fG1top		= (float(totalplayers) * g_Group1Pc);
					fG1top += 11.0;	   // Rank 11 is always End of Group 1
					g1top			 = RoundToCeil(fG1top);

					int g1difference = (g1top - g1bot);
					if (g1difference < 4)
						g1top = (g1bot + 4);

					// Group 2
					float fG2top;
					int	  g2top;
					int	  g2bot;
					g2bot  = g1top + 1;
					fG2top = (float(totalplayers) * g_Group2Pc);
					fG2top += 11.0;
					g2top			 = RoundToCeil(fG2top);

					int g2difference = (g2top - g2bot);
					if (g2difference < 4)
						g2top = (g2bot + 4);

					// Group 3
					float fG3top;
					int	  g3top;
					int	  g3bot;
					g3bot  = g2top + 1;
					fG3top = (float(totalplayers) * g_Group3Pc);
					fG3top += 11.0;
					g3top			 = RoundToCeil(fG3top);

					int g3difference = (g3top - g3bot);
					if (g3difference < 4)
						g3top = (g3bot + 4);

					// Group 4
					float fG4top;
					int	  g4top;
					int	  g4bot;
					g4bot  = g3top + 1;
					fG4top = (float(totalplayers) * g_Group4Pc);
					fG4top += 11.0;
					g4top			 = RoundToCeil(fG4top);

					int g4difference = (g4top - g4bot);
					if (g4difference < 4)
						g4top = (g4bot + 4);

					// Group 5
					float fG5top;
					int	  g5top;
					int	  g5bot;
					g5bot  = g4top + 1;
					fG5top = (float(totalplayers) * g_Group5Pc);
					fG5top += 11.0;
					g5top			 = RoundToCeil(fG5top);

					int g5difference = (g5top - g5bot);
					if (g5difference < 4)
						g5top = (g5bot + 4);

					if (tier == 1)
					{
						wrpoints = ((float(totalplayers) * 1.75) / 6);
						wrpoints += 58.5;
						if (wrpoints < 250.0)
							wrpoints = 250.0;
					}
					else if (tier == 2)
					{
						wrpoints = ((float(totalplayers) * 2.8) / 5);
						wrpoints += 82.15;
						if (wrpoints < 500.0)
							wrpoints = 500.0;
					}
					else if (tier == 3)
					{
						wrpoints = ((float(totalplayers) * 3.5) / 4);
						if (wrpoints < 750.0)
							wrpoints = 750.0;
						else
							wrpoints += 117;
					}
					else if (tier == 4)
					{
						wrpoints = ((float(totalplayers) * 5.74) / 4);
						if (wrpoints < 1000.0)
							wrpoints = 1000.0;
						else
							wrpoints += 164.25;
					}
					else if (tier == 5)
					{
						wrpoints = ((float(totalplayers) * 7) / 4);
						if (wrpoints < 1250.0)
							wrpoints = 1250.0;
						else
							wrpoints += 234;
					}
					else if (tier == 6)
					{
						wrpoints = ((float(totalplayers) * 14) / 4);
						if (wrpoints < 1500.0)
							wrpoints = 1500.0;
						else
							wrpoints += 328;
					}
					else if (tier == 7)
					{
						wrpoints = ((float(totalplayers) * 21) / 4);
						if (wrpoints < 1750.0)
							wrpoints = 1750.0;
						else
							wrpoints += 420;
					}
					else if (tier == 8)
					{
						wrpoints = ((float(totalplayers) * 30) / 4);
						if (wrpoints < 2000.0)
							wrpoints = 2000.0;
						else
							wrpoints += 560;
					}
					else	// no tier set
						wrpoints = 25.0;

					// Round WR points up
					iwrpoints = RoundToCeil(wrpoints);

					// Top 10 Points
					if (rank < 11)
					{
						g_Top10Maps[client][style]++;
						if (rank == 1)
						{
							g_pr_points[client][style] += iwrpoints;
							g_Points[client][style][3] += iwrpoints;
							wrs++;
						}
						else if (rank == 2)
						{
							points = (0.80 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 3)
						{
							points = (0.75 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 4)
						{
							points = (0.70 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 5)
						{
							points = (0.65 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 6)
						{
							points = (0.60 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 7)
						{
							points = (0.55 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 8)
						{
							points = (0.50 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 9)
						{
							points = (0.45 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
						else if (rank == 10)
						{
							points = (0.40 * iwrpoints);
							g_pr_points[client][style] += RoundToCeil(points);
							g_Points[client][style][5] += RoundToCeil(points);
						}
					}
					else if (rank > 10 && rank <= g5top)
					{
						// Group 1-5 Points
						g_GroupMaps[client][style] += 1;
						// Calculate Group Points
						g1points = (iwrpoints * 0.25);
						g2points = (g1points / 1.5);
						g3points = (g2points / 1.5);
						g4points = (g3points / 1.5);
						g5points = (g4points / 1.5);

						if (rank >= g1bot && rank <= g1top)	   // Group 1
						{
							g_pr_points[client][style] += RoundFloat(g1points);
							g_Points[client][style][2] += RoundFloat(g1points);
						}
						else if (rank >= g2bot && rank <= g2top)	// Group 2
						{
							g_pr_points[client][style] += RoundFloat(g2points);
							g_Points[client][style][2] += RoundFloat(g2points);
						}
						else if (rank >= g3bot && rank <= g3top)	// Group 3
						{
							g_pr_points[client][style] += RoundFloat(g3points);
							g_Points[client][style][2] += RoundFloat(g3points);
						}
						else if (rank >= g4bot && rank <= g4top)	// Group 4
						{
							g_pr_points[client][style] += RoundFloat(g4points);
							g_Points[client][style][2] += RoundFloat(g4points);
						}
						else if (rank >= g5bot && rank <= g5top)	// Group 5
						{
							g_pr_points[client][style] += RoundFloat(g5points);
							g_Points[client][style][2] += RoundFloat(g5points);
						}
					}

					// Map Completiton Points
					if (tier == 1)
					{
						g_pr_points[client][style] += 25;
						g_Points[client][style][0] += 25;
					}
					else if (tier == 2)
					{
						g_pr_points[client][style] += 50;
						g_Points[client][style][0] += 50;
					}
					else if (tier == 3)
					{
						g_pr_points[client][style] += 100;
						g_Points[client][style][0] += 100;
					}
					else if (tier == 4)
					{
						g_pr_points[client][style] += 200;
						g_Points[client][style][0] += 200;
					}
					else if (tier == 5)
					{
						g_pr_points[client][style] += 400;
						g_Points[client][style][0] += 400;
					}
					else if (tier == 6)
					{
						g_pr_points[client][style] += 600;
						g_Points[client][style][0] += 600;
					}
					else if (tier == 7)
					{
						g_pr_points[client][style] += 800;
						g_Points[client][style][0] += 800;
					}
					else if (tier == 8)
					{
						g_pr_points[client][style] += 1000;
						g_Points[client][style][0] += 1000;
					}
					else	// no tier
					{
						g_pr_points[client][style] += 13;
						g_Points[client][style][0] += 13;
					}
					break;
				}
			}

			delete jsonObject;
		}

		delete jsonArray;
	}

	// Finished maps amount is stored in memory
	g_pr_finishedmaps[client][style]	  = finishedMaps;
	// Percentage of maps finished
	g_pr_finishedmaps_perc[client][style] = (float(finishedMaps) / float(g_pr_MapCount[0])) * 100.0;

	// WRs
	g_WRs[client][style][0]				  = wrs;

	int	  totalperc						  = g_pr_finishedstages[client][style] + g_pr_finishedbonuses[client][style] + g_pr_finishedmaps[client][style];
	int	  totalcomp						  = g_pr_StageCount + g_pr_BonusCount + g_pr_MapCount[0];
	float ftotalperc;

	ftotalperc = (float(totalperc) / (float(totalcomp))) * 100.0;

	if (IsValidClient(client) && !IsFakeClient(client))
	{
		CS_SetMVPCount(client, (RoundFloat(ftotalperc)));
	}

	// Done checking, update points
	db_updatePoints(client, style);

	LogQueryTime("====== [Surf API] : Finished %s in: %f", func, GetGameTime() - time);
}
