//
// Author: Gaftherman
// Taken and ported from: https://github.com/SamVanheer/halflife-updated/blob/master/dlls/headcrab.cpp
// 
// It was used as a basis: https://github.com/DrAbcrealone/AngelScripts/blob/master/monster/CExpCrab.as
//
// Credits also go to DrAbcrealone
//
// ===================================
//
// This doesn't include anything new or innovative, it's simply the original Half-Life Head-Crab ported to AngelScript.
//
// Usage: In your map script include this
//	#include "../monster_headcrab_custom"
// and in your MapInit() {...}
//	"MonsterCrabCustom::Register();"
//
// ===================================
//
// If you want to modify it or use it as a base for some monster, you are free to use it always giving credits.
//

namespace MonsterCrabCustom
{
	//=========================================================
	// Monster's Anim Events Go Here
	//=========================================================
	const int HC_AE_JUMPATTACK 		= 2;
	
	const float HEADCRAB_DAMAGE 	= g_EngineFuncs.CVarGetFloat( "sk_headcrab_dmg_bite" );
    const float HEADCRAB_HEALTH 	= g_EngineFuncs.CVarGetFloat( "sk_headcrab_health" );

	const int TASKSTATUS_RUNNING 	= 1; // Running task & movement

	const array<string> pIdleSounds = 
	{
		"headcrab/hc_idle1.wav",
		"headcrab/hc_idle2.wav",
		"headcrab/hc_idle3.wav",
		"headcrab/hc_idle4.wav",
		"headcrab/hc_idle5.wav",
	};

	const array<string> pAlertSounds = 
	{
		"headcrab/hc_alert1.wav",
		"headcrab/hc_alert2.wav",
	};

	const array<string> pPainSounds = 
	{
		"headcrab/hc_pain1.wav",
		"headcrab/hc_pain2.wav",
		"headcrab/hc_pain3.wav",
	};
	
	const array<string> pAttackSounds = 
	{
		"headcrab/hc_attack1.wav",
		"headcrab/hc_attack2.wav",
		"headcrab/hc_attack3.wav",
	};

	const array<string> pDeathSounds = 
	{
		"headcrab/hc_die1.wav",
		"headcrab/hc_die2.wav",
	};

	const array<string> pBiteSounds = 
	{
		"headcrab/hc_headbite.wav",
	};

	class CCrabCustom : ScriptBaseMonsterEntity
	{
		private int m_iSoundVolue = 1;
		private	int m_iVoicePitch = PITCH_NORM;

		CCrabCustom()
		{
			@this.m_Schedules = @CHeadCrabschedules;
		}

		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================		
		int	Classify()
		{
			return self.GetClassification( CLASS_ALIEN_PREY );
		}

		//=========================================================
		// Center - returns the real center of the headcrab.  The 
		// bounding box is much larger than the actual creature so 
		// this is needed for targeting
		//=========================================================
		Vector Center()
		{
			return Vector( self.pev.origin.x, self.pev.origin.y, self.pev.origin.z + 6 );
		}

		Vector BodyTarget(const Vector& in posSrc) 
		{ 
			return Center();
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
				case ACT_IDLE: ys = 30;	break;	
					
				case ACT_RUN:			

				case ACT_WALK: ys = 20;	break;

				case ACT_TURN_LEFT:

				case ACT_TURN_RIGHT: ys = 60; break;

				case ACT_RANGE_ATTACK1:	ys = 30; break;

				default: ys = 30; break;
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
				case HC_AE_JUMPATTACK:
				{
					self.pev.flags &= ~FL_ONGROUND;

					g_EntityFuncs.SetOrigin(self, self.pev.origin + Vector ( 0 , 0 , 1) );// take him off ground so engine doesn't instantly reset onground 
					Math.MakeVectors( self.pev.angles );

					Vector vecJumpDir;
					if( self.m_hEnemy.GetEntity() !is null )
					{
						float gravity = g_EngineFuncs.CVarGetFloat( "sv_gravity" );
						if (gravity <= 1)
							gravity = 1;
							
						// How fast does the headcrab need to travel to reach that height given gravity?
						float height = ( self.m_hEnemy.GetEntity().pev.origin.z + self.m_hEnemy.GetEntity().pev.view_ofs.z - self.pev.origin.z );
						if (height < 16)
							height = 16;

						float speed = sqrt( 2 * gravity * height );
						float time = speed / gravity;
						
						// Scale the sideways velocity to get there at the right time
						vecJumpDir = ( self.m_hEnemy.GetEntity().pev.origin + self.m_hEnemy.GetEntity().pev.view_ofs - self.pev.origin );
						vecJumpDir = vecJumpDir * ( 1.0 / time );
						
						// Speed to offset gravity at the desired height
						vecJumpDir.z = speed;

						// Don't jump too far/fast
						float distance = vecJumpDir.Length();
						
						if (distance > 650)
						{
							vecJumpDir = vecJumpDir * ( 650.0 / distance );
						}
					}
					else
					{
						// jump hop, don't care where
						vecJumpDir = Vector( g_Engine.v_forward.x, g_Engine.v_forward.y, g_Engine.v_up.z ) * 350;
					}

					int iSound = Math.RandomLong( 0, 2 );
					if ( iSound != 0 )	
					{
						switch(Math.RandomLong( 0, 2 ))
						{
							case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_attack1.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
							break;

							case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_attack2.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
							break;

							case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_attack3.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
							break;
						}
					}
						
					self.pev.velocity = vecJumpDir;
					self.m_flNextAttack = g_Engine.time + 2;
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

			g_EntityFuncs.SetModel(self, "models/headcrab.mdl");
			g_EntityFuncs.SetSize( self.pev, Vector(-12, -12, 0), Vector(12, 12, 24));
			
			pev.solid			        = SOLID_SLIDEBOX;
			pev.movetype		        = MOVETYPE_STEP;
			self.m_bloodColor	        = BLOOD_COLOR_GREEN;
			pev.effects		            = 0;	
			self.pev.health 			= HEADCRAB_HEALTH;
			self.pev.view_ofs		    = Vector( 0, 0, 20 );// position of the eyes relative to monster's origin.
			self.pev.yaw_speed			= 5;//!!! should we put this in the monster's changeanim function since turn rates may vary with state/anim?
			self.m_flFieldOfView        = 0.5;// indicates the width of this monster's forward view cone ( as a dotproduct result )
			self.m_MonsterState		    = MONSTERSTATE_NONE;
			
			self.m_FormattedName 		= "Head Crab";
		
			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
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

			for(uint i = 0; i < pAttackSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pAttackSounds[i]);
			}

			for(uint i = 0; i < pDeathSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pDeathSounds[i]);
			}

			for(uint i = 0; i < pBiteSounds.length();i++)
			{
				g_SoundSystem.PrecacheSound(pBiteSounds[i]);
			}

			g_Game.PrecacheModel("models/headcrab.mdl");
		}
		

		//=========================================================
		// RunTask 
		//=========================================================
		void RunTask( Task@ pTask )
		{
			switch ( pTask.iTask )
			{
				case TASK_RANGE_ATTACK1:
				case TASK_RANGE_ATTACK2:
				{
					if ( self.m_fSequenceFinished )
					{
						self.TaskComplete();
						SetTouch( null );
						self.m_IdealActivity = ACT_IDLE;
					}
					break;
				}
				default: BaseClass.RunTask( pTask );
			}
		}
		
		//=========================================================
		// LeapTouch - this is the headcrab's touch function when it
		// is in the air
		//=========================================================
		void LeapTouch( CBaseEntity @pOther )
		{
			if ( pOther.pev.takedamage == DAMAGE_NO )
				return;
			
			if ( pOther.Classify() == Classify() )
				return;
			
			// Don't hit if back on ground
			if ( !self.pev.FlagBitSet( FL_ONGROUND ) )
			{
				BiteSound();

				pOther.TakeDamage( self.pev, self.pev, HEADCRAB_DAMAGE, DMG_SLASH  );
			}

			SetTouch( null );
		}

		//=========================================================
		// PrescheduleThink
		//=========================================================
		void PrescheduleThink()
		{
			// Make the crab coo a little bit in combat state
			if ( self.m_MonsterState == MONSTERSTATE_COMBAT && Math.RandomFloat( 0, 5 ) < 0.1 )
			{
				IdleSound();
			}
		}
		
		void StartTask( Task@ pTask )
		{
			self.m_iTaskStatus = TASKSTATUS_RUNNING;

			switch ( pTask.iTask )
			{
				case TASK_RANGE_ATTACK1:
				{					
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "headcrab/hc_attack1.wav", m_iSoundVolue, ATTN_NORM, 0, m_iVoicePitch);
					self.m_IdealActivity = ACT_RANGE_ATTACK1;
					SetTouch ( TouchFunction(LeapTouch) );
					break;
				}
				default: BaseClass.StartTask( pTask );
			}
		}

		//=========================================================
		// CheckRangeAttack1
		//=========================================================
		bool CheckRangeAttack1( float flDot, float flDist )
		{
			if ( self.pev.FlagBitSet( FL_ONGROUND ) && flDist <= 256 && flDot >= 0.65 )
			{
				return true;
			}
			return false;
			
		}

		//=========================================================
		// CheckRangeAttack2
		//=========================================================
		bool CheckRangeAttack2( float flDot, float flDist )
		{	
		
			return false;
			
			/* BUGBUG: Why is this code here?  There is no ACT_RANGE_ATTACK2 animation.  I've disabled it for now.
			if ( ( self.pev.FlagBitSet( FL_ONGROUND ) && flDist > 64 && flDist <= 256 && flDot >= 0.5 )
			{
				return true;
			}
			return false;
			*/
		}

		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
		{	

			if ( bitsDamageType & DMG_ACID != 0)
				flDamage = 0;

			return BaseClass.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);
		}

		//=========================================================
		// IdleSound
		//=========================================================
		void IdleSound()
		{
			switch (Math.RandomLong( 0, 4 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_idle1.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_idle2.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_idle3.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 3: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_idle4.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 4: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_idle5.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;
			}
		}
		
		//=========================================================
		// AlertSound 
		//=========================================================
		void AlertSound()
		{			
			switch (Math.RandomLong( 0, 1 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_alert1.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_alert2.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;
			}
		}

		//=========================================================
		// PainSound 
		//=========================================================
		void PainSound()
		{
			switch (Math.RandomLong( 0, 2 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_pain1.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_pain2.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_pain3.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;
			}
		}

		//=========================================================
		// AttackSound 
		//=========================================================
		void AttackSound()
		{
			switch (Math.RandomLong( 0, 2 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "headcrab/hc_attack1.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "headcrab/hc_attack2.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "headcrab/hc_attack3.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;
			}
		}

		//=========================================================
		// DeathSound 
		//=========================================================
		void DeathSound()
		{
			switch (Math.RandomLong( 0, 1 ))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_die1.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "headcrab/hc_die2.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch); 
				break;
			}
		}
		
		//=========================================================
		// BiteSound
		//=========================================================
		void BiteSound()
		{
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "headcrab/hc_headbite.wav", m_iSoundVolue, ATTN_IDLE, 0, m_iVoicePitch );
		}

		Schedule@ GetScheduleOfType( int Type )
		{	
			switch	( Type )
			{
				case SCHED_RANGE_ATTACK1: return slHCRangeAttack1;
			}
			return BaseClass.GetScheduleOfType( Type );
		}
	}

	array<ScriptSchedule@>@ CHeadCrabschedules;

	ScriptSchedule slHCRangeAttack1 
	(
		bits_COND_ENEMY_OCCLUDED	|
		bits_COND_NO_AMMO_LOADED,
		0,
		"HC Range Attack1"
	);

	ScriptSchedule slHCRangeAttack1Fast 
	(
		bits_COND_ENEMY_OCCLUDED	|
		bits_COND_NO_AMMO_LOADED,
		0,
		"HC RA Fast"
	);

	void InitSchedules()
	{
		slHCRangeAttack1.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slHCRangeAttack1.AddTask( ScriptTask(TASK_FACE_IDEAL) );
		slHCRangeAttack1.AddTask( ScriptTask(TASK_RANGE_ATTACK1) );
		slHCRangeAttack1.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );
		slHCRangeAttack1.AddTask( ScriptTask(TASK_FACE_IDEAL) );
		slHCRangeAttack1.AddTask( ScriptTask(TASK_WAIT_RANDOM, float(0.5)) );

		slHCRangeAttack1Fast.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slHCRangeAttack1Fast.AddTask( ScriptTask(TASK_FACE_IDEAL) );
		slHCRangeAttack1Fast.AddTask( ScriptTask(TASK_RANGE_ATTACK1) );
		slHCRangeAttack1Fast.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );

		array<ScriptSchedule@> scheds = 
		{
			slHCRangeAttack1, 
			slHCRangeAttack1Fast
		};

		@CHeadCrabschedules = @scheds;
	}

	void Register()
	{
		InitSchedules();
		g_CustomEntityFuncs.RegisterCustomEntity( "MonsterCrabCustom::CCrabCustom", "monster_headcrab_custom" );
	}
}
