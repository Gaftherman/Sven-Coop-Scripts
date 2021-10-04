/*
* This script implements all other scripts in your map
*/

#include "hl_nuked/base"
#include "hl_nuked/weapon_hlnuked_handgun"
#include "hl_nuked/weapon_hlnuked_shotgun"
#include "hl_nuked/weapon_hlnuked_chaingun"
#include "hl_nuked/weapon_hlnuked_rpg"
#include "hl_nuked/weapon_hlnuked_devastator"

void MapInit()
{
	RegisterHLNukedhandgun();
	RegisterHLNukedShotgun();
	RegisterHLNukedChaingun();
	RegisterHLNukedRpg();
	RegisterHLNukedDevastator();
}