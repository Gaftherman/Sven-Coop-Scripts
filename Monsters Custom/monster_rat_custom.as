//
// Author: Gaftherman
// Taken and ported from: https://github.com/SamVanheer/halflife-updated/blob/master/dlls/rat.cpp
//
// ===================================
//
// Why is this here?
// 1.- I use it as a base to create enemies.
// 2.- Do not really expect more point for which I stand out because I did it.
//
// Usage: In your map script include this
//	#include "../monster_rat_custom"
// and in your MapInit() {...}
//	"MonsterRatCustom::Register();"
//
// ===================================
//

namespace MonsterRatCustom
{
	//=========================================================
	// Monster's Anim Events Go Here
	//=========================================================

	class CRatCustom : ScriptBaseMonsterEntity
	{
		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return	self.GetClassification( CLASS_INSECT );
		}

		//=========================================================
		// SetYawSpeed - allows each sequence to have a different
		// turn rate associated with it.
		//=========================================================
		void SetYawSpeed()
		{
			int ys;

			switch ( self.m_Activity )
			{
				case ACT_IDLE:

				default: ys = 45; break;
			}

			self.pev.yaw_speed = ys;
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
			Precache( );

			g_EntityFuncs.SetModel( self, "models/bigrat.mdl");
			g_EntityFuncs.SetSize( self.pev, Vector( 0, 0, 0 ), Vector( 0, 0, 0 ) );

			pev.solid				= SOLID_SLIDEBOX;
			pev.movetype			= MOVETYPE_STEP;
			self.m_bloodColor		= BLOOD_COLOR_RED;
			self.pev.health			= 8;
			pev.view_ofs			= Vector ( 0, 0, 3 );// position of the eyes relative to monster's origin.
			self.m_flFieldOfView	= 0.5;// indicates the width of this monster's forward view cone ( as a dotproduct result )
			self.m_MonsterState		= MONSTERSTATE_NONE;

			self.m_FormattedName	= "Rat";

			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
			g_Game.PrecacheModel("models/bigrat.mdl");
		}	

		//=========================================================
		// AI Schedules Specific to this monster
		//=========================================================
	}

	void Register()
	{
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterRatCustom::CRatCustom", "monster_rat_custom");
	}
}
