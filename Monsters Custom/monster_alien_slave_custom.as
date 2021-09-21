//
// Author: Gaftherman
// Taken and ported from: https://github.com/SamVanheer/halflife-updated/blob/master/dlls/islave.cpp
//
// ===================================
//
// This doesn't include anything new or innovative, it's simply the original Half-Life Alien Slave ported to AngelScript.
//
// Some bugs that I couldn't fix (mb for my low knowledge in AS):
//
// - Inside IRelationship there is a flag called SF_MONSTER_WAIT_UNTIL_PROVOKED
// which I don't know how it works
//
// - The slave's secondary function of reviving fallen allies has been disabled.
// Why? It's because being near a dead slave, he simply starts spinning or simply prioritizes the player and decides to let him disappear.
// 
// - CallForHelp is disabled because it is not available in AS (I think)
//
// Usage: In your map script include this
//	#include "../monster_alien_slave_custom"
// and in your MapInit() {...}
//	"MonsterSlaveCustom::Register();"
//
// ===================================
//
// If you want to modify it or use it as a base for some monster, you are free to use it always giving credits.
//


namespace MonsterSlaveCustom
{

	//=========================================================
	// Monster's Anim Events Go Here
	//=========================================================

	const int ISLAVE_AE_CLAW			= 1;
	const int ISLAVE_AE_CLAWRAKE		= 2;
	const int ISLAVE_AE_ZAP_POWERUP		= 3;
	const int ISLAVE_AE_ZAP_SHOOT		= 4;
	const int ISLAVE_AE_ZAP_DONE		= 5;

	const int ISLAVE_MAX_BEAMS 			= 8;

	const int ISLAVE_HEALTH = int(g_EngineFuncs.CVarGetFloat( "sk_islave_health" ));
	const int ISLAVE_DAMAGE_CLAW = int(g_EngineFuncs.CVarGetFloat( "sk_islave_dmg_claw" ));
	const int ISLAVE_DAMAGE_CLAWRAKE = int(g_EngineFuncs.CVarGetFloat( "sk_islave_dmg_clawrake" ));
	const int ISLAVE_DAMAGE_ZAP = int(g_EngineFuncs.CVarGetFloat( "sk_islave_dmg_zap" ));

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

	const array<string> pPainSounds = 
	{
		"aslave/slv_pain1.wav",
		"aslave/slv_pain2.wav",
	};

	const array<string> pDeathSounds = 
	{
		"aslave/slv_die1.wav",
		"aslave/slv_die2.wav",
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

	class CSlaveCustom : ScriptBaseMonsterEntity
	{
		private int m_iBravery;
		private array <CBeam@> m_pBeam( ISLAVE_MAX_BEAMS );
		private int m_iBeams;
		private float m_flNextAttack;
		private int	m_voicePitch;
		private EHandle m_hDead;

		CSlaveCustom()
		{
			@this.m_Schedules = @CSlaveCustom_schedules;
		}

		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return	self.GetClassification(CLASS_ALIEN_MILITARY);
		}

		/*int IRelationship( CBaseEntity@ pTarget )
		{
			if ( (pTarget.IsPlayer()) )
				if ( (pev.spawnflags & SF_MONSTER_WAIT_UNTIL_PROVOKED) != 0 && !( self.m_afMemory & bits_MEMORY_PROVOKED ) )
					return R_NO;

			return self.IRelationship( pTarget );
		}*/

		/*void CallForHelp( const char *szClassname, float flDist, EHANDLE hEnemy, Vector &vecLocation )
		{
			// ALERT( at_aiconsole, "help " );

			// skip ones not on my netname
			if ( FStringNull( pev->netname ))
				return;

			CBaseEntity *pEntity = NULL;

			while ((pEntity = UTIL_FindEntityByString( pEntity, "netname", STRING( pev->netname ))) != NULL)
			{
				float d = (pev->origin - pEntity->pev->origin).Length();
				if (d < flDist)
				{
					CBaseMonster *pMonster = pEntity->MyMonsterPointer( );
					if (pMonster)
					{
						pMonster->m_afMemory |= bits_MEMORY_PROVOKED;
						pMonster->PushEnemy( hEnemy, vecLocation );
					}
				}
			}
		}*/


		//=========================================================
		// ALertSound - scream
		//=========================================================
		void AlertSound()
		{
			if ( self.m_hEnemy.GetEntity() !is null )
			{
				g_SoundSystem.PlaySentenceGroup( self.edict(), "SLV_ALERT", 0.85, ATTN_NORM, 0, m_voicePitch);

				//CallForHelp( "monster_alien_slave", 512, m_hEnemy, m_vecEnemyLKP );
			}
		}

		//=========================================================
		// IdleSound
		//=========================================================
		void IdleSound()
		{
			if (Math.RandomLong( 0, 2 ) == 0)
			{
				g_SoundSystem.PlaySentenceGroup( self.edict(), "SLV_IDLE", 0.85, ATTN_NORM, 0, m_voicePitch);
			}
		}

		//=========================================================
		// PainSound
		//=========================================================
		void PainSound()
		{
			if( Math.RandomLong( 0, 2 ) == 0)
			{
				switch( Math.RandomLong( 0, 1 ) )
				{
					case 0:
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "aslave/slv_pain1.wav", 1, ATTN_NORM, 0, m_voicePitch );	
					break;

					case 1:
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "aslave/slv_pain2.wav", 1, ATTN_NORM, 0, m_voicePitch );	
					break;
				}
			}
		}

		//=========================================================
		// DieSound
		//=========================================================
		void DeathSound()
		{
			switch( Math.RandomLong( 0, 1 ) )
			{
				case 0:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "aslave/slv_die1.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;

				case 1:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "aslave/slv_die2.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;
			}
		}

		//=========================================================
		// AttackHitSounds
		//=========================================================
		void AttackHitSounds()
		{
			switch( Math.RandomLong( 0, 2 ) )
			{
				case 0:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_strike1.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;

				case 1:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_strike2.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;

				case 2:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_strike3.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;
			}
		}

		//=========================================================
		// AttackMissSounds
		//=========================================================
		void AttackMissSounds()
		{
			switch( Math.RandomLong( 0, 1 ) )
			{
				case 0:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_miss1.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;

				case 1:
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "zombie/claw_miss2.wav", 1, ATTN_NORM, 0, m_voicePitch );	
				break;
			}
		}

		//=========================================================
		// ISoundMask - returns a bit mask indicating which types
		// of sounds this monster regards. 
		//=========================================================
		int ISoundMask()
		{
			return  bits_SOUND_WORLD    |
					bits_SOUND_COMBAT   |
					bits_SOUND_DANGER   |
					bits_SOUND_PLAYER;
		}

		void Killed( entvars_t@ pevAttacker, int iGib )
		{
			//g_Game.AlertMessage( at_console, "Entity was killed\n" );
			ClearBeams();
			BaseClass.Killed( pevAttacker, iGib );
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

			case ACT_WALK: ys = 50; break;	

			case ACT_RUN: ys = 70; break;		

			case ACT_IDLE: ys = 50; break;			

			default: ys = 90; break;	 

			}

			self.pev.yaw_speed = ys;
		}

		//=========================================================
		// HandleAnimEvent - catches the monster-specific messages
		// that occur when tagged animation frames are played.
		//
		// Returns number of events handled, 0 if none.
		//=========================================================
		void HandleAnimEvent( MonsterEvent@ pEvent )
		{
			// g_Game.AlertMessage( at_console, "event" + "%1" + " : " + "%2" + "\n", pEvent.event, self.pev.frame );
			switch( pEvent.event )
			{
				case ISLAVE_AE_CLAW:
				{
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, ISLAVE_DAMAGE_CLAW, DMG_SLASH );
					if ( pHurt !is null )
					{
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							Math.MakeVectors( pev.angles );
							pHurt.pev.punchangle.z = -18;
							pHurt.pev.punchangle.x = 5;
						}
						// Play a random attack hit sound
						AttackHitSounds();
					}
					else
					{
						// Play a random attack miss sound
						AttackMissSounds();					
					}
				}
				break;
				
				case ISLAVE_AE_CLAWRAKE:
				{
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, ISLAVE_DAMAGE_CLAWRAKE, DMG_SLASH );
					if ( pHurt !is null )
					{
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							Math.MakeVectors( pev.angles );
							pHurt.pev.punchangle.z = -18;
							pHurt.pev.punchangle.x = 5;
						}
						// Play a random attack hit sound
						AttackHitSounds();
					}
					else
					{
						// Play a random attack miss sound
						AttackMissSounds();
					}
				}
				break;

				case ISLAVE_AE_ZAP_POWERUP:
				{
					Math.MakeAimVectors( self.pev.angles );

					if (m_iBeams == 0)
					{
						Vector vecSrc = pev.origin + g_Engine.v_forward * 2;
						NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSrc );
							message.WriteByte(TE_DLIGHT);
							message.WriteCoord(vecSrc.x);	// X
							message.WriteCoord(vecSrc.y);	// Y
							message.WriteCoord(vecSrc.z);	// Z
							message.WriteByte( 12 );		// radius * 0.1
							message.WriteByte( 255 );		// r
							message.WriteByte( 180 );		// g
							message.WriteByte( 96 );		// b
							message.WriteByte( 20 / 1 );	// time * 10
							message.WriteByte( 0 );			// decay * 0.1
						message.End();
					}
					if( m_hDead.GetEntity() !is null )
					{
						WackBeam( -1, m_hDead );
						WackBeam( 1, m_hDead );
					}
					else
					{
						ArmBeam( -1 );
						ArmBeam( 1 );
						BeamGlow();
					}

					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "debris/zap4.wav", 1, ATTN_NORM, 0, 100 + m_iBeams * 10 );
					self.pev.skin = m_iBeams / 2;
				}
				break;

				case ISLAVE_AE_ZAP_SHOOT:
				{
					ClearBeams();

					if( m_hDead.GetEntity() !is null )
					{
						Vector vecDest = m_hDead.GetEntity().pev.origin + Vector( 0, 0, 38 );
						TraceResult trace;
						g_Utility.TraceHull( vecDest, vecDest, dont_ignore_monsters, human_hull, m_hDead.GetEntity().edict(), trace );

						if ( trace.fStartSolid != 0 )
						{
							CBaseEntity@ pNew = g_EntityFuncs.Create( "monster_alien_slave", m_hDead.GetEntity().pev.origin, m_hDead.GetEntity().pev.angles, false, null );
							CBaseMonster@ pNewMonster = pNew.MyMonsterPointer();
							pNew.pev.spawnflags |= 1;
							WackBeam( -1, pNew );
							WackBeam( 1, pNew );
							g_EntityFuncs.Remove( m_hDead );
							g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hassault/hw_shoot1.wav", 1, ATTN_NORM, 0, Math.RandomLong( 130, 160 ) );
	
							/*CBaseEntity@ pEffect = g_EntityFuncs.Create( "test_effect", pNew.Center(), self.pev.angles, false, null );
							pEffect.Use( self, self, USE_ON, 1 );*/
							
							break;
						}
					}
					g_WeaponFuncs.ClearMultiDamage();

					Math.MakeAimVectors( self.pev.angles );

					ZapBeam( -1 );
					ZapBeam( 1 );

					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hassault/hw_shoot1.wav", 1, ATTN_NORM, 0, Math.RandomLong( 130, 160 ) );
					//g_SoundSystem.StopSound( self.edict(), CHAN_WEAPON, "debris/zap4.wav" );
					g_WeaponFuncs.ApplyMultiDamage(self.pev, self.pev);

					m_flNextAttack = g_Engine.time + Math.RandomFloat( 0.5, 4.0 );
				}
				break;

				case ISLAVE_AE_ZAP_DONE:
				{
					ClearBeams();
				}
				break;

				default: BaseClass.HandleAnimEvent( pEvent ); break;
			}
		}

		bool CheckRangeAttack1( float flDot, float flDist )
		{ 
			if(m_flNextAttack > g_Engine.time )
			{
				return false;
			}
			
			return BaseClass.CheckRangeAttack1( flDot, flDist );
		}

		//=========================================================
		// CheckRangeAttack2 - check bravery and try to resurect dead comrades
		//=========================================================
		bool CheckRangeAttack2( float flDot, float flDist )
		{ 
			// Works strange xd

			return false;

			/*
			m_hDead = null;
			m_iBravery = 0;

			CBaseEntity@ pEntity = null;

			while((@pEntity = g_EntityFuncs.FindEntityByClassname( pEntity, "monster_alien_slave*" )) != null )
			{
				TraceResult tr;

				g_Utility.TraceLine( self.EyePosition(), pEntity.EyePosition(), ignore_monsters, self.edict(), tr);
				if(tr.flFraction == 1 || tr.pHit is pEntity.edict())
				{
					if (pEntity.pev.deadflag != DEAD_NO)
					{
						float d = (self.pev.origin - pEntity.pev.origin).Length();
						if(d < flDist)
						{
							m_hDead = pEntity;
							flDist = d;
						}
						m_iBravery--;
					}
					else
					{
						m_iBravery++;
					}
				}
			}

			if( m_hDead.GetEntity() !is null)
				return true;
			else
				return false;*/

		}	

		//=========================================================
		// StartTask
		//=========================================================
		void StartTask( Task@ pTask )
		{
			ClearBeams();

			BaseClass.StartTask( pTask );
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
			Precache();

			g_EntityFuncs.SetModel( self, "models/islave.mdl");
			g_EntityFuncs.SetSize( self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX );

			pev.solid				= SOLID_SLIDEBOX;
			pev.movetype			= MOVETYPE_STEP;
			self.m_bloodColor		= BLOOD_COLOR_GREEN;
			pev.effects				= 0;
			pev.health				= ISLAVE_HEALTH;
			pev.view_ofs			= Vector ( 0, 0, 64 );// position of the eyes relative to monster's origin.
			self.m_flFieldOfView	= VIEW_FIELD_WIDE;// NOTE: we need a wide field of view so npc will notice player and say hello
			self.m_MonsterState		= MONSTERSTATE_NONE;
			self.m_afCapability		= bits_CAP_HEAR | bits_CAP_TURN_HEAD | bits_CAP_RANGE_ATTACK2 | bits_CAP_DOORS_GROUP;

			m_voicePitch			= Math.RandomLong( 85, 110 );
			self.m_FormattedName	= "Alien Slave";

			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
			g_Game.PrecacheModel("models/islave.mdl");
			g_Game.PrecacheModel("models/islave.mdl");
			g_Game.PrecacheModel("sprites/lgtning.spr");
			g_SoundSystem.PrecacheSound("debris/zap1.wav");
			g_SoundSystem.PrecacheSound("debris/zap4.wav");
			g_SoundSystem.PrecacheSound("weapons/electro4.wav");
			g_SoundSystem.PrecacheSound("hassault/hw_shoot1.wav");
			g_SoundSystem.PrecacheSound("zombie/zo_pain2.wav");
			g_SoundSystem.PrecacheSound("headcrab/hc_headbite.wav");
			g_SoundSystem.PrecacheSound("weapons/cbar_miss1.wav");

			g_Game.PrecacheOther( "test_effect" );

			for(uint i = 0; i < pAttackHitSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAttackHitSounds[i]);
			}	
			for(uint i = 0; i < pAttackMissSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAttackMissSounds[i]);
			}			
			for(uint i = 0; i < pPainSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pPainSounds[i]);
			}			
			for(uint i = 0; i < pDeathSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pDeathSounds[i]);
			}
		}	

		//=========================================================
		// TakeDamage - get provoked when injured
		//=========================================================
		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
		{
			if(pevAttacker is null)
				return 0;

			CBaseEntity@ pAttacker = g_EntityFuncs.Instance( pevAttacker );

			if(self.CheckAttacker( pAttacker ))
				return 0;

			self.m_afMemory |= bits_MEMORY_PROVOKED;

			return BaseClass.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);
		}

		void TraceAttack( entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType)
		{
			if (bitsDamageType & DMG_SHOCK != 0)
				return;

			BaseClass.TraceAttack( pevAttacker, flDamage, vecDir, ptr, bitsDamageType );
		}

		Schedule@ GetSchedule()
		{

			ClearBeams();
			
			/*if(self.pev.spawnflags != 0)
			{
				self.pev.spawnflags = 0;
				return GetScheduleOfType( SCHED_RELOAD );
			}*/
			

			if ( self.HasConditions( bits_COND_HEAR_SOUND ) )
			{
				CSound@ pSound;
				@pSound = self.PBestSound();

				//ASSERT( pSound != NULL );
				if( pSound !is null && (pSound.m_iType & bits_SOUND_DANGER) == 1 )
					return GetScheduleOfType( SCHED_TAKE_COVER_FROM_BEST_SOUND );
	
				if( (pSound.m_iType & bits_SOUND_COMBAT) == 1 )
					self.m_afMemory |= bits_MEMORY_PROVOKED;
			}

			switch (self.m_MonsterState)
			{
			case MONSTERSTATE_COMBAT:
				// dead enemy
				if( self.HasConditions(bits_COND_ENEMY_DEAD) )
				{
					// call base class, all code to handle dead enemies is centralized there.
					return BaseClass.GetSchedule();
				}

				if ( self.pev.health < 20 || m_iBravery < 0)
				{
					if ( !self.HasConditions(bits_COND_CAN_MELEE_ATTACK1))
					{
						self.m_failSchedule = SCHED_CHASE_ENEMY;
						if (self.HasConditions( bits_COND_LIGHT_DAMAGE | bits_COND_HEAVY_DAMAGE))
						{
							return GetScheduleOfType( SCHED_TAKE_COVER_FROM_ENEMY );
						}
						if (self.HasConditions( bits_COND_SEE_ENEMY ) && self.HasConditions( bits_COND_ENEMY_FACING_ME ) )
						{
							//g_Game.AlertMessage( at_console, "exposed\n" );
							return GetScheduleOfType( SCHED_TAKE_COVER_FROM_ENEMY );
						}
					}
				}
				break;
			}
			return BaseClass.GetSchedule();
		}

		Schedule@ GetScheduleOfType( int Type )
		{
			switch( Type )
			{
				case SCHED_FAIL:
				if (self.HasConditions( bits_COND_CAN_MELEE_ATTACK1 ))
				{
					return BaseClass.GetScheduleOfType( SCHED_MELEE_ATTACK1 );
				}
				break;

				case SCHED_RANGE_ATTACK1: return slSlaveAttack1;

				case SCHED_RANGE_ATTACK2: return slSlaveAttack1;
			}
			return BaseClass.GetScheduleOfType( Type );
		}

		//=========================================================
		// ArmBeam - small beam from arm to nearby geometry
		//=========================================================
		void ArmBeam( int side )
		{
			TraceResult tr;
			float flDist = 1.0;
			
			if (m_iBeams >= ISLAVE_MAX_BEAMS)
				return;

			Math.MakeVectors( self.pev.angles );
			Vector vecSrc = self.pev.origin + g_Engine.v_up * 36 + g_Engine.v_right * side * 16 + g_Engine.v_forward * 32;

			for (int i = 0; i < 3; i++)
			{
				Vector vecAim = g_Engine.v_right * side * Math.RandomFloat( 0, 1 ) + g_Engine.v_up * Math.RandomFloat( -1, 1 );
				TraceResult tr1;
				
				g_Utility.TraceLine( vecSrc, vecSrc + vecAim * 512, dont_ignore_monsters, self.edict(), tr1);
				if (flDist > tr1.flFraction)
				{
					tr = tr1;
					flDist = tr.flFraction;
				}
			}

			// Couldn't find anything close enough
			if ( flDist == 1.0 )
				return;

			g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_CROWBAR );

			@m_pBeam[m_iBeams] = g_EntityFuncs.CreateBeam( "sprites/lgtning.spr", 30 );
			if( m_pBeam[m_iBeams] is null )
				return;

			m_pBeam[m_iBeams].PointEntInit( tr.vecEndPos, self.entindex() );
			m_pBeam[m_iBeams].SetEndAttachment( side < 0 ? 2 : 1 );
			// m_pBeam[m_iBeams].SetColor( 180, 255, 96 );
			m_pBeam[m_iBeams].SetColor( 96, 128, 16 );
			m_pBeam[m_iBeams].SetBrightness( 64 );
			m_pBeam[m_iBeams].SetNoise( 80 );
			m_iBeams++;
		}

		//=========================================================
		// BeamGlow - brighten all beams
		//=========================================================
		void BeamGlow()
		{
			int b = m_iBeams * 32;
			if (b > 255)
				b = 255;

			for (int i = 0; i < m_iBeams; i++)
			{
				if (m_pBeam[i].GetBrightness() != 255) 
				{
					m_pBeam[i].SetBrightness( b );
				}
			}
		}

		//=========================================================
		// WackBeam - regenerate dead colleagues
		//=========================================================
		void WackBeam( int side, CBaseEntity@ pEntity )
		{
			Vector vecDest;
			float flDist = 1.0;
			
			if (m_iBeams >= ISLAVE_MAX_BEAMS)
				return;

			if (pEntity is null)
				return;

			@m_pBeam[m_iBeams] = g_EntityFuncs.CreateBeam( "sprites/lgtning.spr", 30 );
			if( m_pBeam[m_iBeams] is null )
				return;
			m_pBeam[m_iBeams].PointEntInit( pEntity.Center(), self.entindex() );
			m_pBeam[m_iBeams].SetEndAttachment( side < 0 ? 2 : 1 );
			m_pBeam[m_iBeams].SetColor( 180, 255, 96 );
			m_pBeam[m_iBeams].SetBrightness( 255 );
			m_pBeam[m_iBeams].SetNoise( 80 );
			m_iBeams++;
		}

		//=========================================================
		// ZapBeam - heavy damage directly forward
		//=========================================================
		void ZapBeam( int side )
		{
			Vector vecSrc, vecAim;
			TraceResult tr;

			if (m_iBeams >= ISLAVE_MAX_BEAMS)
				return;

			vecSrc = self.pev.origin + g_Engine.v_up * 36;
			vecAim = self.ShootAtEnemy( vecSrc );
			float deflection = 0.01;
			vecAim = vecAim + side * g_Engine.v_right * Math.RandomFloat( 0, deflection ) + g_Engine.v_up * Math.RandomFloat( -deflection, deflection );
			g_Utility.TraceLine( vecSrc, vecSrc + vecAim * 1024, dont_ignore_monsters, self.edict(), tr);

			@m_pBeam[m_iBeams] = g_EntityFuncs.CreateBeam( "sprites/lgtning.spr", 50 );
			if( m_pBeam[m_iBeams] is null )
				return;

			m_pBeam[m_iBeams].PointEntInit( tr.vecEndPos, self.entindex() );
			m_pBeam[m_iBeams].SetEndAttachment( side < 0 ? 2 : 1 );
			m_pBeam[m_iBeams].SetColor( 180, 255, 96 );
			m_pBeam[m_iBeams].SetBrightness( 255 );
			m_pBeam[m_iBeams].SetNoise( 20 );
			m_iBeams++;

			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			if (pEntity !is null && pEntity.pev.takedamage != 0)
			{
				pEntity.TraceAttack( pev, ISLAVE_DAMAGE_ZAP, vecAim, tr, DMG_SHOCK );
			}

			g_SoundSystem.EmitAmbientSound( self.edict(), tr.vecEndPos, "weapons/electro4.wav", 0.5, ATTN_NORM, 0, Math.RandomLong( 140, 160 ) );
		}

		//=========================================================
		// ClearBeams - remove all beams
		//=========================================================
		void ClearBeams()
		{
			for(int i = 0; i < ISLAVE_MAX_BEAMS; i++)
			{
				if (m_pBeam[i] !is null)
				{
					g_EntityFuncs.Remove( m_pBeam[i] );
					@m_pBeam[i] = @null;
				}
			}
			m_iBeams = 0;
			self.pev.skin = 0;

			g_SoundSystem.StopSound( self.edict(), CHAN_WEAPON, "debris/zap4.wav" );
		}

	}

	array<ScriptSchedule@>@ CSlaveCustom_schedules;

	ScriptSchedule	slSlaveAttack1
	(
			bits_COND_CAN_MELEE_ATTACK1 |
			bits_COND_HEAR_SOUND 		|
			bits_COND_HEAVY_DAMAGE, 

			bits_SOUND_DANGER,
			"Slave Range Attack1"
	);

	void InitSchedules()
	{
		slSlaveAttack1.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSlaveAttack1.AddTask( ScriptTask(TASK_FACE_IDEAL) );
		slSlaveAttack1.AddTask( ScriptTask(TASK_RANGE_ATTACK1) );

		array<ScriptSchedule@> scheds =
		{
			slSlaveAttack1
		};

		@CSlaveCustom_schedules = @scheds;
	}

	void Register()
	{
		InitSchedules();
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterSlaveCustom::CSlaveCustom", "monster_alien_slave_custom");
	}
}