#if defined _surftimer_included
 #endinput
#endif
#define _surftimer_included

// Replays separation
#include <cstrike>
#include <sdktools>
// Part of SMLib
#define MAX_WEAPONS				48	// Max number of weapons availabl

/*  Natives  */

/**
 * Checks if a client's timer is active.
 *
 * @param client		The client's ID.
 * @return					true if the client's timer is active. False otherwise.
 */
native bool surftimer_GetTimerStatus(int client);

/**
 * Stops a client's timer.
 *
 * @param client		The client's ID.
 */
native void surftimer_StopTimer(int client);

/**
 * Starts a client's timer.
 *
 * @param client		The client's ID.
 */
native void surftimer_EmulateStartButtonPress(int client);

/**
 * Finishes a client's run.
 *
 * @param client		The client's ID.
 */
native void surftimer_EmulateStopButtonPress(int client);

/**
 * Retrives a client's current runtime.
 *
 * @param client			The client's ID.
 * @return						The current runtime of the client.
 */
native float surftimer_GetCurrentTime(int client);

/**
 * Checks if a client has the VIP status.
 *
 * @param client			The client's ID.
 * @return						true if the client's has the VIP status. False otherwise.
 */
native bool surftimer_IsClientVip(int client);

/**
 * Retrieves the rank of a client.
 *
 * @param client			The client's ID.
 * @return						The rank of the client. -1 on failure.
 */
native int surftimer_GetPlayerRank(int client);

/**
 * Retrieves a client's rank.
 *
 * @param client			The client's ID.
 * @return						The points of the client. -1 on failure.
 */
native int surftimer_GetPlayerPoints(int client);

/**
 * Retrieves the skillgroup of a client
 *
 * @param client			The client's ID.
 * @param str					The string to convert.
 * @return						Skillgroup as a string. Unranked on failure.
 */
native void surftimer_GetPlayerSkillgroup(int client, char[] str);

/**
 * Retrieves the current map tier.
 *
 * @return						Current map tier.
 */
native int surftimer_GetMapTier();

/**
 * Retrieves the number of stages on the current map.
 *
 * @return						Number of stages on the current map. 0 if the map is linear.
 */
native int surftimer_GetMapStages();

/**
 * Retrieves a client's name with colors.
 *
 * @param client			The client's ID.
 * @param str					The string to convert.
 * @return						The client's name with colors. Invalid on failure.
 */
native void surftimer_GetPlayerNameColored(int client, char[] str);

/**
 * Retrieves the current map's WR holder and the associated time.
 *
 * @param szname				String to store the WR holder's name.
 * @param sztime				String to store the WR holder's time.
 * @param time					float to store the WR holder's time.
 * @return						The number of players who have finished the current map.
 */
native int surftimer_GetMapData(char[] szname, char[] sztime, float& time);

/**
 * Retrieves the wr/pb info regarding the current bonus a players is on
 *
 * @param client				The client's ID.
 * @param szWRname				String to store the Bonus WR holder's name.
 * @param WRtime				float to store the Bonus WR holder's time.
 * @param pbtime				float to store the Bonus PB holder's time.
 * @return						The number of players who have finished the current bonus.
 */
native int surftimer_GetBonusData(int client, char[] szWRname, float& WRtime, float& PBtime);

/**
 * Retrieves the current map's stage WR holder and the associated times.
 *
 * @param client				The client's ID.
 * @param szWRname				String to store the stage WR holder's name.
 * @param WRtime				float to store the stage WR holder's time.
 * @param pbtime				float to store the stage PB holder's time.
 * @return						The number of players who have finished the current stage.
 */
native int surftimer_GetStageData(int client, char[] szWRname, float& WRtime, float& PBtime);

/**
 * Retrieves the client's data.
 *
 * @param client			The client's ID.
 * @param time				String to store the client's map time.
 * @param rank				int to store the client's map rank.
 * @param country			String to store the client's country.
 * @param countryCode			String to store the client's countryCode.
 * @param continentCode			String to store the client's continentCode.
 */
native void surftimer_GetPlayerData(int& client, float& time, int& rank, char[] country, char countryCode[3], char continentCode[3]);

/**
 * Retrieves the client's current info.
 *
 * @param client			The client's ID.
 * @param iWrcpTimer		Int to store the client's WRCP timer.
 * @param iPracMode			Int to store the client's Practice mode.
 * @param iStage			Int to store the client's current stage.
 * @param iBonus			Int to store the client's current bonus.
 */
native void surftimer_GetPlayerInfo(int& client, int& iWrcpTimer, int& iPracMode, int& iStage, int& iBonus);

/**
 * Retrieves the client's current sync.
 *
 * @param client			The client's ID.
 * @return					Client's sync.
 */
native float surftimer_GetClientSync(int client);

/**
 * Retrieves the client's current style.
 *
 * @param client			The client's ID.
 * @return					Current client's style.
 */
native int surftimer_GetClientStyle(int client);

/**
 * Teleport a client safely, without triggering end touches
 * and sets the client's location correctly.
 *
 * @param client					The client's ID.
 * @param fDestination		The teleport location.
 * @param fAngle					The teleport angle.
 * @param fVelocity				The teleport velocity.
 * @param bStopTimer			Whether or not to stop the client's timer. Defaults to false.
 * @return								true on success, false otherwise.
 */
native bool surftimer_SafeTeleport(int client, float fDestination[3], float fAngle[3], float fVelocity[3], bool bStopTimer = false);

/*  FORWARDS  */

/**
 * Called when a client finishes a map.
 *
 * @param client			The client's ID.
 * @return						Plugin_Handled, to stop the client from searching.
 */
forward Action surftimer_OnMapFinished(int client, float fRunTime, char sRunTime[54], float PBDiff, float WRDiff, int rank, int total, int style);

/**
 * Called when a player reaches a checkpoint zone or a stage.
 *
 * @param client			The client's ID.
 * @return						Plugin_Handled, to stop the client from searching.
 */
forward Action surftimer_OnCheckpoint(int client, float fRunTime, char sRunTime[54], float fPbCp, char sPbDiff[16], float fSrCp, char sSrDiff[16]);


/**
 * Called when a client finishes a bonus.
 *
 * @param client			The client's ID.
 * @return						Plugin_Handled, to stop the player from searching.
 */
forward Action surftimer_OnBonusFinished(int client, float fRunTime, char sRunTime[54], float fPBDiff, float fSRDiff, int rank, int total, int bonusid, int style);

/**
 * Called when a client finishes a map in practice mode
 *
 * @param client			The client's ID.
 * @return						Plugin_Handled, to stop the player from searching.
 */
forward Action surftimer_OnPracticeFinished(int client, float fRunTime, char sRunTime[54]);

/**
 * Called when a client sets a new record
 *
 * @param client			The client's ID.
 * @param style				Style index.
 * @param time				Time set by the player.
 * @param timeDif			Time difference with the former record.
 * @param bonusGroup	Group of the bonus. -1 if the record isn't a bonus.
 */
forward void surftimer_OnNewRecord(int client, int style, char[] time, char[] timeDif, int bonusGroup);

/**
 * Called when a client sets a new WRCP
 *
 * @param client			The client's ID.
 * @param style				Style index.
 * @param time				Time set by the player.
 * @param timeDif			Time difference with the former record.
 * @param stage			  	The id of the stage of the WRCP.
 * @param fRunTime			Run time for the WRCP in float.
 */
forward void surftimer_OnNewWRCP(int client, int style, char[] time, char[] timeDif, int stage, float fRunTime);

/**
 * Converts steamid2 (STEAM_X:Y:Z) to the accountid which will returned.
 */
stock int SteamId2ToAccountId(const char[] steamid)
{
    return (StringToInt(steamid[10]) * 2) + (steamid[8] == '1' ? 1 : 0);
}

///////////////////////////////////////////////// Replays separation
// new frame info
enum struct frame_t
{
	float pos[3];
	float ang[2];
	int buttons;
	int flags;
	MoveType mt;
}

// old frame info
enum struct FrameInfo
{
	int PlayerButtons;
	int PlayerImpulse;
	float ActualVelocity[3];
	float PredictedVelocity[3];
	float PredictedAngles[2];
	CSWeaponID NewWeapon;
	int PlayerSubtype;
	int PlayerSeed;
	int AdditionalFields;
	int Pause;
}

enum struct FileHeader
{
	int BinaryFormatVersion;
	char Time[32];
	char Playername[MAX_NAME_LENGTH];
	int Checkpoints;
	int TickCount;
	float InitialPosition[3];
	float InitialAngles[3];
	ArrayList Frames;
}

/**
 * Copies a 1 dimensional static array.
 *
 * @param array			Static Array to copy from.
 * @param newArray		New Array to copy to.
 * @param size			Size of the array (or number of cells to copy)
 * @noreturn
 */
stock void Array_Copy(const any[] array, any[] newArray, int size)
{
	for (int i=0; i < size; i++) {
		newArray[i] = array[i];
	}
}

stock bool IsValidClient(int client)
{
	if (client >= 1 && client <= MaxClients && IsClientInGame(client))
		return true;
	return false;
}

/**
 * Removes all weapons of a client.
 * You can specify a weapon it shouldn't remove and if to
 * clear the player's ammo for a weapon when it gets removed.
 *
 * @param client 		Client Index.
 * @param exclude		If not empty, this weapon won't be removed from the client.
 * @param clearAmmo		If true, the ammo the player carries for all removed weapons are set to 0 (primary and secondary).
 * @return				Number of removed weapons.
 */
stock int Client_RemoveAllWeapons(int client, const char[] exclude="", bool clearAmmo=false)
{
	int offset = Client_GetWeaponsOffset(client) - 4;

	int numWeaponsRemoved = 0;
	for (int i=0; i < MAX_WEAPONS; i++) {
		offset += 4;

		int weapon = GetEntDataEnt2(client, offset);

		if (!Weapon_IsValid(weapon)) {
			continue;
		}

		if (exclude[0] != '\0' && Entity_ClassNameMatches(weapon, exclude)) {
			Client_SetActiveWeapon(client, weapon);
			continue;
		}

		if (clearAmmo) {
			Client_SetWeaponPlayerAmmoEx(client, weapon, 0, 0);
		}

		if (RemovePlayerItem(client, weapon)) {
			Entity_Kill(weapon);
		}

		numWeaponsRemoved++;
	}

	return numWeaponsRemoved;
}

/**
 * Gets the offset for a client's weapon list (m_hMyWeapons).
 * The offset will saved globally for optimization.
 *
 * @param client		Client Index.
 * @return				Weapon list offset or -1 on failure.
 */
stock int Client_GetWeaponsOffset(int client)
{
	static int offset = -1;

	if (offset == -1) {
		offset = FindDataMapInfo(client, "m_hMyWeapons");
	}

	return offset;
}

/*
 * Checks whether the entity is a valid weapon or not.
 *
 * @param weapon		Weapon Entity.
 * @return				True if the entity is a valid weapon, false otherwise.
 */
stock bool Weapon_IsValid(int weapon)
{
	if (!IsValidEdict(weapon)) {
		return false;
	}

	return Entity_ClassNameMatches(weapon, "weapon_", true);
}

/**
 * Checks if an entity (partially) matches a specific entity class.
 *
 * @param entity		Entity Index.
 * @param className		Classname String.
 * @partialMatch		If to do a partial classname check.
 * @return				True if the classname matches, false otherwise.
 */
stock bool Entity_ClassNameMatches(int entity, const char[] className, bool partialMatch=false)
{
	char entity_className[64];
	Entity_GetClassName(entity, entity_className, sizeof(entity_className));

	if (partialMatch) {
		return (StrContains(entity_className, className) != -1);
	}

	return StrEqual(entity_className, className);
}

/**
 * Kills an entity on the next frame (delayed).
 * It is safe to use with entity loops.
 * If the entity is is player ForcePlayerSuicide() is called.
 *
 * @param kenny			Entity index.
 * @param killChildren	When true, kennys children are killed too.
 * @return 				True on success, false otherwise.
 */
stock bool Entity_Kill(int kenny, bool killChildren=false)
{
	if (Entity_IsPlayer(kenny)) {
		// Oh My God! They Killed Kenny!!
		ForcePlayerSuicide(kenny);
		return true;
	}

	if(killChildren){
		return AcceptEntityInput(kenny, "KillHierarchy");
	}
	else {
		return AcceptEntityInput(kenny, "Kill");
	}
}

/**
 * Changes the active/current weapon of a player by Index.
 * Note: No changing animation will be played !
 *
 * @param client		Client Index.
 * @param weapon		Index of a valid weapon.
 */
stock void Client_SetActiveWeapon(int client, int weapon)
{
	SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
	ChangeEdictState(client, FindDataMapInfo(client, "m_hActiveWeapon"));
}

/**
 * Sets the primary and secondary ammo the player carries for a specific weapon index.
 *
 * @param client		Client Index.
 * @param weapon		Weapon Entity Index.
 * @param primaryAmmo	Primary ammo stock value from the client, if -1 the value is untouched.
 * @param secondaryAmmo	Secondary ammo stock value from the client, if -1 the value is untouched.
 */
stock void Client_SetWeaponPlayerAmmoEx(int client, int weapon, int primaryAmmo=-1, int secondaryAmmo=-1)
{
	int offset_ammo = FindDataMapInfo(client, "m_iAmmo");

	if (primaryAmmo != -1) {
		int offset = offset_ammo + (Weapon_GetPrimaryAmmoType(weapon) * 4);
		SetEntData(client, offset, primaryAmmo, 4, true);
	}

	if (secondaryAmmo != -1) {
		int offset = offset_ammo + (Weapon_GetSecondaryAmmoType(weapon) * 4);
		SetEntData(client, offset, secondaryAmmo, 4, true);
	}
}

/**
 * Gets the Classname of an entity.
 * This is like GetEdictClassname(), except it works for ALL
 * entities, not just edicts.
 *
 * @param entity			Entity index.
 * @param buffer			Return/Output buffer.
 * @param size				Max size of buffer.
 * @return					Number of non-null bytes written.
 */
stock int Entity_GetClassName(int entity, char[] buffer, int size)
{
	return GetEntPropString(entity, Prop_Data, "m_iClassname", buffer, size);
}

/**
 * Checks if an entity is a player or not.
 * No checks are done if the entity is actually valid,
 * the player is connected or ingame.
 *
 * @param entity			Entity index.
 * @return 				True if the entity is a player, false otherwise.
 */
stock bool Entity_IsPlayer(int entity)
{
	if (entity < 1 || entity > MaxClients) {
		return false;
	}

	return true;
}

/*
 * Gets the primary ammo Type (int offset)
 *
 * @param weapon		Weapon Entity.
 * @return				Primary ammo type value.
 */
stock int Weapon_GetPrimaryAmmoType(int weapon)
{
	return GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
}

/*
 * Gets the secondary ammo Type (int offset)
 *
 * @param weapon		Weapon Entity.
 * @return				Secondary ammo type value.
 */
stock int Weapon_GetSecondaryAmmoType(int weapon)
{
	return GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoType");
}
/////////////////////////////////////////////////
public SharedPlugin:__pl_surftimer =
{
	name = "surftimer",
	file = "surftimer.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public __pl_surftimer_SetNTVOptional()
{
	MarkNativeAsOptional("surftimer_GetTimerStatus");
	MarkNativeAsOptional("surftimer_StopTimer");
	MarkNativeAsOptional("surftimer_EmulateStartButtonPress");
	MarkNativeAsOptional("surftimer_EmulateStopButtonPress");
	MarkNativeAsOptional("surftimer_GetCurrentTime");
	MarkNativeAsOptional("surftimer_ClientIsVIP");
	MarkNativeAsOptional("surftimer_GetServerRank");
	MarkNativeAsOptional("surftimer_SafeTeleport");
	MarkNativeAsOptional("surftimer_OnNewRecord");
}
