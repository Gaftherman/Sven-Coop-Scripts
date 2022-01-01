//
// Author: Gaftherman
// Taken and ported from: https://github.com/SamVanheer/halflife-updated/blob/master/dlls/gman.cpp
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
//	"MonsterGmanCustom::Register();"
//
// ===================================
//
// If you want to modify it or use it as a base for some monster, you are free to use it always giving credits.
//

namespace MonsterGmanCustom
{
	//=========================================================
	// Monster's Anim Events Go Here
	//=========================================================
	class CGMan : ScriptBaseMonsterEntity
	{
		private EHandle m_hPlayer;
		private EHandle m_hTalkTarget;
		private float m_flTalkTime;

		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return self.GetClassification( CLASS_NONE );
		}

		//=========================================================
		// SetYawSpeed - allows each sequence to have a different
		// turn rate associated with it.
		//=========================================================
		void SetYawSpeed()
		{
			int ys;

			switch( self.m_Activity )
			{
				case ACT_IDLE: ys = 90;

				default: ys = 90; break;
			}

			self.pev.yaw_speed = ys;
		}

		//=========================================================
		// HandleAnimEvent - catches the monster-specific messages
		// that occur when tagged animation frames are played.
		//=========================================================
		void HandleAnimEvent( MonsterEvent@ pEvent )
		{
			switch( pEvent.event )
			{
				case 0:

				default: BaseClass.HandleAnimEvent( pEvent ); break;
			}
		}

		//=========================================================
		// ISoundMask - generic monster can't hear.
		//=========================================================
		int ISoundMask()
		{
			return bits_SOUND_NONE;
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
			Precache( );

			g_EntityFuncs.SetModel( self, "models/gman.mdl");
			g_EntityFuncs.SetSize( self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX);

			pev.solid				= SOLID_SLIDEBOX;
			pev.movetype			= MOVETYPE_STEP;
			self.m_bloodColor		= DONT_BLEED;
			self.pev.health			= 100;
			self.m_flFieldOfView	= 0.5;// indicates the width of this monster's forward view cone ( as a dotproduct result )
			self.m_MonsterState		= MONSTERSTATE_NONE;

			self.m_FormattedName	= "G-Man";

			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
			g_Game.PrecacheModel("models/gman.mdl");
		}	

		//=========================================================
		// AI Schedules Specific to this monster
		//=========================================================
		void StartTask( Task@ pTask )
		{
			switch( pTask.iTask )
			{
				case TASK_WAIT:
				if ( m_hPlayer.GetEntity() is null)
				{
					m_hPlayer = g_EntityFuncs.FindEntityByClassname( null, "player" );
				}
				break;
			}

			BaseClass.StartTask( pTask );
		}

		void RunTask( Task@ pTask )
		{
			switch ( pTask.iTask )
			{
				case TASK_WAIT:
				// look at who I'm talking to
				if( m_flTalkTime > g_Engine.time && m_hTalkTarget.GetEntity() !is null)
				{
					float yaw = self.VecToYaw( m_hTalkTarget.GetEntity().pev.origin - self.pev.origin ) - self.pev.angles.y;

					if( yaw > 180 )
						yaw -= 360;

					if( yaw < -180 )
						yaw += 360;

					// turn towards vector
					self.SetBoneController( 0, yaw );
				}
				// look at player, but only if playing a "safe" idle animation
				else if( m_hPlayer.GetEntity() !is null && self.pev.sequence == 0 )
				{
					float yaw = self.VecToYaw( m_hPlayer.GetEntity().pev.origin - self.pev.origin ) - self.pev.angles.y;

					if( yaw > 180 )
						yaw -= 360;

					if( yaw < -180 )
						yaw += 360;
						
					// turn towards vector
					self.SetBoneController( 0, yaw );
				}
				else 
				{
					self.SetBoneController( 0, 0 );
				}
				BaseClass.RunTask( pTask );
				break;
				
				default: self.SetBoneController( 0, 0 ); BaseClass.RunTask( pTask ); break;
			}
		}

		//=========================================================
		// Override all damage
		//=========================================================
		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
		{
			self.pev.health = self.pev.max_health / 2; // always trigger the 50% damage aitrigger

			if ( flDamage > 0 )
			{
				self.SetConditions(bits_COND_LIGHT_DAMAGE);
			}

			if ( flDamage >= 20 )
			{
				self.SetConditions(bits_COND_HEAVY_DAMAGE);
			}
			
			return 0;
		}
		
		void TraceAttack( entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType)
		{
			g_Utility.Ricochet( ptr.vecEndPos, 1.0 );
			g_WeaponFuncs.AddMultiDamage( @pevAttacker, @self, flDamage, bitsDamageType );
		}

		void PlayScriptedSentence(const string& in szSentence, float duration, float volume, float attenuation, const bool bConcurrent, CBaseEntity@ pListener)
		{
			self.PlayScriptedSentence( szSentence, duration, volume, attenuation, bConcurrent, pListener );

			m_flTalkTime = g_Engine.time + duration;
			m_hTalkTarget = @pListener;
		}
	}

	void Register()
	{
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterGmanCustom::CGMan", "monster_gman_custom");
	}
}