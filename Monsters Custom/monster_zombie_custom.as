


// Original Author: Goodman3 https://github.com/goodman3/gm3s_svencoop_scripts
// To contact him: 272992860@qq.com
//
// It was used as a base https://github.com/DrAbcrealone/AngelScripts
//
// Only the zombie climber function was removed
//
// The credits go to DrAbcrealone & Goodman3
// ===================================
//
// This doesn't include anything new or innovative, it's simply the original Half-Life Zombie ported to AngelScript.
//
// - Zombie recoil has been disabled. To activate it remove the /*  */ on the line 150 and 153
//
// Usage: In your map script include this
//	#include "../monster_zombie_custom"
// and in your MapInit() {...}
//	"MonsterZombieCustom::Register();"
//
// ===================================
//
// If you want to modify it or use it as a base for some monster, you are free to use it always giving credits.
//

namespace MonsterZombieCustom
{
	//=========================================================
	// Monster's Anim Events Go Here
	//=========================================================

	const int ZOMBIE_AE_ATTACK_RIGHT 	= 1;
	const int ZOMBIE_AE_ATTACK_LEFT 	= 2;
	const int ZOMBIE_AE_ATTACK_BOTH 	= 3;

	const int ZOMBIE_FLINCH_DELAY 		= 2; // at most one flinch every n secs

	const int ZOMBIE_HEALTH 			= int(g_EngineFuncs.CVarGetFloat( "sk_zombie_health" ));
	const int ZOMBIE_ONESLASH 			= int(g_EngineFuncs.CVarGetFloat( "sk_zombie_dmg_one_slash" ));
	const int ZOMBIE_BOTHSLASH 			= int(g_EngineFuncs.CVarGetFloat( "sk_zombie_dmg_both_slash" ));

	const array<string> pAttackHitSounds =
	{
		"zombie/claw_strike1.wav",
		"zombie/claw_strike2.wav",
		"zombie/claw_strike3.wav",
	};
	const array<string> pAttackMissSounds =
	{
		"zombie/claw_miss1.wav",
		"zombie/claw_miss2.wav",
	};
	const array<string> pAttackSounds =
	{
		"zombie/zo_attack1.wav",
		"zombie/zo_attack2.wav",
	};
	const array<string> pIdleSounds =
	{
		"zombie/zo_idle1.wav",
		"zombie/zo_idle2.wav",
		"zombie/zo_idle3.wav",
		"zombie/zo_idle4.wav",
	};
	const array<string> pAlertSounds =
	{
		"zombie/zo_alert10.wav",
		"zombie/zo_alert20.wav",
		"zombie/zo_alert30.wav",
	};
	const array<string> pPainSounds =
	{
		"zombie/zo_pain1.wav",
		"zombie/zo_pain2.wav",
	};

	CBaseEntity@ CheckTraceHullAttack( CBaseMonster@ pThis, float flDist, int iDamage, int iDmgType ) 
	{
		TraceResult tr;

		if (pThis.IsPlayer()) 
		{
			Math.MakeVectors( pThis.pev.angles );
		} 
		else 
		{
			Math.MakeAimVectors( pThis.pev.angles );
		}

		Vector vecStart = pThis.pev.origin;
		vecStart.z += pThis.pev.size.z * 0.5;
		Vector vecEnd = vecStart + (g_Engine.v_forward * flDist );

		g_Utility.TraceHull( vecStart, vecEnd, dont_ignore_monsters, head_hull, pThis.edict(), tr );
		
		if ( tr.pHit !is null ) 
		{
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );
			if ( iDamage > 0 ) 
			{
				pEntity.TakeDamage( pThis.pev, pThis.pev, iDamage, iDmgType );
			}
			return pEntity;
		}
		return null;
	}
	
	class CMonsterZombieCustom : ScriptBaseMonsterEntity
	{
	
		private int m_iSoundVolume = 1;
		private	int m_iVoicePitch = PITCH_NORM;	
		private float m_flNextFlinch;

		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return	self.GetClassification( CLASS_ALIEN_MONSTER );
		}	

		//=========================================================
		// SetYawSpeed - allows each sequence to have a different
		// turn rate associated with it.
		//=========================================================
		void SetYawSpeed()
		{
			int ys;

			ys = 120;

			/*
			switch ( self.m_Activity )
			{
			}
			*/

			self.pev.yaw_speed = ys;
		}

		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
		{
			// Take 30% damage from bullets
			if ( (bitsDamageType & DMG_BULLET) != 0 )
			{
				/*Vector vecDir = self.pev.origin - (pevInflictor.absmin + pevInflictor.absmax) * 0.5;
				vecDir = vecDir.Normalize();
				float flForce = self.DamageForce( flDamage );
				self.pev.velocity = self.pev.velocity + vecDir * flForce;*/
				flDamage *= 0.3;
			}
			
			// HACK HACK -- until we fix this.
			if ( self.IsAlive() )
				PainSound();
				
			return BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
		}

		void PainSound()
		{
			int pitch = 95 + Math.RandomLong( 0, 9 );

			if (Math.RandomLong( 0, 5 ) < 2)
			{
				switch (Math.RandomLong( 0, 1 ))
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_pain1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
					break;
					
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_pain1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
					break;
				}
			}
		
		}

		void AlertSound()
		{
			int pitch = 95 + Math.RandomLong( 0, 9 );

			switch (Math.RandomLong( 0, 2 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_alert10.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_alert20.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_alert30.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;
			}
		}	

		void IdleSound()
		{
			int pitch = 100 + Math.RandomLong( -5, 5 );

			// Play a random idle sound
			switch (Math.RandomLong( 0, 3 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_idle1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_idle2.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_idle3.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 3: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_idle4.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;
			}
		}	

		void AttackSound()
		{
			int pitch = 100 + Math.RandomLong( -5, 5 );

			switch (Math.RandomLong( 0, 1 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_attack1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch);
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "zombie/zo_attack2.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;
			}
		}

		void AttackHitSound()
		{
			int pitch = 100 + Math.RandomLong( -5, 5 );

			// Play a random attack sound
			switch (Math.RandomLong( 0, 2 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_strike1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_strike2.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_strike3.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;
			}	
		}

		void AttackMissSound()
		{
			int pitch = 100 + Math.RandomLong( -5, 5 );

			switch (Math.RandomLong( 0, 1 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_miss1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_miss1.wav", m_iSoundVolume, ATTN_NORM, 0, pitch); 
				break;
			}	
		}
		
		void HandleAnimEvent( MonsterEvent@ pEvent )
		{
			switch( pEvent.event )
			{
				case ZOMBIE_AE_ATTACK_RIGHT:
				{
					// do stuff for this event.
					//ALERT ( at_aiconsole, "Slash right!\n" );
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, ZOMBIE_ONESLASH, DMG_SLASH );
					if ( pHurt !is null )
					{
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							pHurt.pev.punchangle.z = -18;
							pHurt.pev.punchangle.x = 5;
							pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_right * 100;
						}
						// Play a random attack hit sound
						AttackHitSound();
					}
					else
					{
						// Play a random attack miss sound
						AttackMissSound();
					}
					
					if (Math.RandomLong( 0, 1 ) > 0 )
					{
						AttackSound();
					}
				}
				break;		

				case ZOMBIE_AE_ATTACK_LEFT:
				{
					// do stuff for this event.
					//ALERT ( at_aiconsole, "Slash left!\n" );
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, ZOMBIE_ONESLASH, DMG_SLASH );
					if ( pHurt !is null )
					{
					
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							pHurt.pev.punchangle.z = 18;
							pHurt.pev.punchangle.x = 5;
							pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_right * 100;
						}
						// Play a random attack hit sound
						AttackHitSound();
					}
					else
					{
						// Play a random attack miss sound
						AttackMissSound();
					}
					
					if (Math.RandomLong( 0, 1 ) > 0 )
					{
						AttackSound();
					}
				}
				break;

				case ZOMBIE_AE_ATTACK_BOTH:
				{
					// do stuff for this event.
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, ZOMBIE_BOTHSLASH, DMG_SLASH );
					if ( pHurt !is null )
					{
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							pHurt.pev.punchangle.x = 5;
							pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_right * 100;
						}
						// Play a random attack hit sound
						AttackHitSound();
					}
					else
					{
						// Play a random attack miss sound
						AttackMissSound();
					}
					
					if (Math.RandomLong( 0, 1 ) > 0 )
					{
						AttackSound();
					}
				}
				break;
				
				default: BaseClass.HandleAnimEvent( pEvent ); break;
			}
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
		
			Precache();
			
			g_EntityFuncs.SetModel(self, "models/zombie.mdl");
			g_EntityFuncs.SetSize(self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX);
			
			pev.solid			        = SOLID_SLIDEBOX;
			pev.movetype		        = MOVETYPE_STEP;
			self.m_bloodColor	        = BLOOD_COLOR_GREEN;
			self.pev.health 			= ZOMBIE_HEALTH;
			self.pev.view_ofs		   	= VEC_VIEW;
			self.m_flFieldOfView        = 0.5;
			self.m_MonsterState		    = MONSTERSTATE_NONE;
			self.m_afCapability			= bits_CAP_DOORS_GROUP;
				
			self.m_FormattedName = "Zombie";

			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
			g_Game.PrecacheModel("models/zombie.mdl");

			for(uint i = 0; i < pAttackHitSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAttackHitSounds[i]);
			}	
			for(uint i = 0; i < pAttackMissSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAttackMissSounds[i]);
			}			
			for(uint i = 0; i < pAttackSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAttackSounds[i]);
			}			
			for(uint i = 0; i < pIdleSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pIdleSounds[i]);
			}
			for(uint i = 0; i < pAlertSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAlertSounds[i]);
			}			
			for(uint i = 0; i < pPainSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pPainSounds[i]);
			}
		}	

		int IgnoreConditions()
		{
			int iIgnore = 0;
			
			if ((self.m_Activity == ACT_MELEE_ATTACK1) || (self.m_Activity == ACT_MELEE_ATTACK1))
			{	
				if (m_flNextFlinch >= g_Engine.time)
					iIgnore |= (bits_COND_LIGHT_DAMAGE|bits_COND_HEAVY_DAMAGE);
			}

			if ((self.m_Activity == ACT_SMALL_FLINCH) || (self.m_Activity == ACT_BIG_FLINCH))
			{
				if (m_flNextFlinch < g_Engine.time)
					m_flNextFlinch = g_Engine.time + ZOMBIE_FLINCH_DELAY;
			}

			return iIgnore;
		}

		// No range attacks
		bool CheckRangeAttack1( float flDot, float flDist )  
		{ 
			return false; 
		}

		bool CheckRangeAttack2( float flDot, float flDist )  
		{ 
			return false; 
		}
	}

	void Register()
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "MonsterZombieCustom::CMonsterZombieCustom", "monster_zombie_custom" );
	}
}