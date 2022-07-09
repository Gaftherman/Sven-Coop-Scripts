namespace MonsterHuman
{
	const int BARNEY_AE_DRAW			= 2;
	const int BARNEY_AE_SHOOT			= 3;
	const int BARNEY_AE_HOLSTER			= 4;
	const int BARNEY_BODY_GUNHOLSTERED	= 0;
	const int BARNEY_BODY_GUNDRAWN		= 1;
	const int BARNEY_BODY_GUNGONE		= 2;

	class CHuman : ScriptBaseMonsterEntity
	{
		private int	m_iBrassShell, m_iShotgunShell, m_iSawLink, m_iSawShell, m_cClipSize, m_iWeapon;
        private float m_checkAttackTime, m_flNextFearScream, m_flpainTime;
		private bool m_lastAttackCheck, m_bGunDrawn;

		CHuman()
		{
			@this.m_Schedules = @monster_human_schedules;
		}

		int ObjectCaps()
		{
			if( self.IsPlayerAlly() )
				return FCAP_IMPULSE_USE;
			else
				return BaseClass.ObjectCaps();
		}
		
		void RunTask( Task@ pTask )
		{
			switch ( pTask.iTask )
			{
				case TASK_RANGE_ATTACK1:
				{
					//if(self.m_hEnemy().IsValid() && (self.m_hEnemy().GetEntity().IsPlayer()))
					self.pev.framerate = 1.5f;

						//m_flThinkDelay = 0.0f;


					//Friendly fire stuff.
					if( !self.NoFriendlyFire() )
					{
						self.ChangeSchedule( self.GetScheduleOfType ( SCHED_FIND_ATTACK_POINT ) );
						return;
					}

					BaseClass.RunTask( pTask );
					break;
				}
				case TASK_RELOAD:
				{
					self.MakeIdealYaw( self.m_vecEnemyLKP );
					self.ChangeYaw( int(self.pev.yaw_speed) );

					if( self.m_fSequenceFinished )
					{
						self.m_cAmmoLoaded = m_cClipSize;
						self.ClearConditions(bits_COND_NO_AMMO_LOADED);
						//m_Activity = ACT_RESET;

						self.TaskComplete();
					}
					break;
				}
				default: BaseClass.RunTask( pTask ); break;
			}
		}

		int ISoundMask()
		{
			return	bits_SOUND_WORLD	|
					bits_SOUND_COMBAT	|
					bits_SOUND_BULLETHIT|
					bits_SOUND_CARCASS	|
					bits_SOUND_MEAT		|
					bits_SOUND_GARBAGE	|
					bits_SOUND_DANGER	|
					bits_SOUND_PLAYER;
		}

		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return	self.GetClassification( CLASS_HUMAN_MILITARY  );
		}	 

		//=========================================================
		// SetYawSpeed - allows each sequence to have a different
		// turn rate associated with it.
		//=========================================================
		void SetYawSpeed()
		{
			self.pev.yaw_speed = 360;
		}

		//=========================================================
		// CheckRangeAttack1
		//=========================================================
		bool CheckRangeAttack1( float flDot, float flDist )
		{	
			if( flDist <= 2048 && flDot >= 0.5 && self.NoFriendlyFire())
			{
				CBaseEntity@ pEnemy = self.m_hEnemy.GetEntity();
				TraceResult tr;
				Vector shootOrigin = self.pev.origin + Vector( 0, 0, 55 );
				Vector shootTarget = (pEnemy.BodyTarget( shootOrigin ) - pEnemy.Center()) + self.m_vecEnemyLKP;
				g_Utility.TraceLine( shootOrigin, shootTarget, dont_ignore_monsters, self.edict(), tr );
							
				if( tr.flFraction == 1.0 || tr.pHit is pEnemy.edict() )
					return true;
			}

			return false;
		}

		Vector GetGunPosition()
		{
			return self.pev.origin + Vector(0, 0, 60);
		}

		//=========================================================
		// FirePistol - shoots one round from the pistol at
		// the enemy barney is facing.
		//=========================================================
		void FirePistol()
		{
			Math.MakeVectors( self.pev.angles );
			Vector vecShootOrigin = self.pev.origin + Vector( 0, 0, 55 );
			Vector vecShootDir = self.ShootAtEnemy( vecShootOrigin );
			Vector angDir = Math.VecToAngles( vecShootDir );

			self.FireBullets(1, vecShootOrigin, vecShootDir, VECTOR_CONE_2DEGREES, 1024, BULLET_MONSTER_9MM );
			Vector vecShellVelocity = g_Engine.v_right * Math.RandomFloat(40,90) + g_Engine.v_up * Math.RandomFloat(75,200) + g_Engine.v_forward * Math.RandomFloat(-40, 40);
			g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * -17, vecShellVelocity, self.pev.angles.y, m_iBrassShell, TE_BOUNCE_SHELL); 

			int pitchShift = Math.RandomLong( 0, 20 );
			if( pitchShift > 10 )// Only shift about half the time
				pitchShift = 0;
			else
				pitchShift -= 5;
			
			self.SetBlending( 0, angDir.x );
			self.pev.effects = EF_MUZZLEFLASH;
			GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "weapons/pl_gun3.wav", 1, ATTN_NORM, 0, PITCH_NORM + pitchShift );

			if( self.pev.movetype != MOVETYPE_FLY && self.m_MonsterState != MONSTERSTATE_PRONE )
			{
				self.m_flAutomaticAttackTime = g_Engine.time + Math.RandomFloat(0.2, 0.5);
			}

			// UNDONE: Reload?
			--self.m_cAmmoLoaded;// take away a bullet!
		}

		//==============//
		// Fire Python //
		//=============//
		void FirePython()
		{
			Math.MakeVectors( self.pev.angles );
			Vector vecShootOrigin = self.pev.origin + Vector( 0, 0, 55 );
			Vector vecShootDir = self.ShootAtEnemy( vecShootOrigin );
			Vector angDir = Math.VecToAngles( vecShootDir );

			self.FireBullets(1, vecShootOrigin, vecShootDir, VECTOR_CONE_2DEGREES, 1024, BULLET_PLAYER_357 );
			Vector vecShellVelocity = g_Engine.v_right * Math.RandomFloat(40,90) + g_Engine.v_up * Math.RandomFloat(75,200) + g_Engine.v_forward * Math.RandomFloat(-40, 40);
			g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * -17, vecShellVelocity, self.pev.angles.y, m_iBrassShell, TE_BOUNCE_SHELL); 

			int pitchShift = Math.RandomLong( 0, 20 );
			if( pitchShift > 10 )// Only shift about half the time
				pitchShift = 0;
			else
				pitchShift -= 5;
			
			self.SetBlending( 0, angDir.x );
			self.pev.effects = EF_MUZZLEFLASH;
			GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "weapons/357_shot1.wav", 1, ATTN_NORM, 0, PITCH_NORM + pitchShift );

			if( self.pev.movetype != MOVETYPE_FLY && self.m_MonsterState != MONSTERSTATE_PRONE )
			{
				self.m_flAutomaticAttackTime = g_Engine.time + 0.75;
			}

			// UNDONE: Reload?
			--self.m_cAmmoLoaded;// take away a bullet!
		}

		//==============//
		// Fire Eagle //
		//=============//
		void FireEagle()
		{
			Math.MakeVectors( self.pev.angles );
			Vector vecShootOrigin = self.pev.origin + Vector( 0, 0, 55 );
			Vector vecShootDir = self.ShootAtEnemy( vecShootOrigin );
			Vector angDir = Math.VecToAngles( vecShootDir );

			self.FireBullets(1, vecShootOrigin, vecShootDir, VECTOR_CONE_2DEGREES, 1024, BULLET_PLAYER_357 );
			Vector vecShellVelocity = g_Engine.v_right * Math.RandomFloat(40,90) + g_Engine.v_up * Math.RandomFloat(75,200) + g_Engine.v_forward * Math.RandomFloat(-40, 40);
			g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * -17, vecShellVelocity, self.pev.angles.y, m_iBrassShell, TE_BOUNCE_SHELL); 

			int pitchShift = Math.RandomLong( 0, 20 );
			if( pitchShift > 10 )// Only shift about half the time
				pitchShift = 0;
			else
				pitchShift -= 5;
			
			self.SetBlending( 0, angDir.x );
			self.pev.effects = EF_MUZZLEFLASH;
			GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "weapons/de_shot1.wav", 1, ATTN_NORM, 0, PITCH_NORM + pitchShift );

			if( self.pev.movetype != MOVETYPE_FLY && self.m_MonsterState != MONSTERSTATE_PRONE )
			{
				self.m_flAutomaticAttackTime = g_Engine.time + Math.RandomFloat(0.22, 0.5);
			}

			// UNDONE: Reload?
			--self.m_cAmmoLoaded;// take away a bullet!
		}

		//==============//
		// Fire Shotgun //
		//==============//
		void FireShotgun()
		{
			Math.MakeVectors( self.pev.angles );
			Vector vecShootOrigin = self.pev.origin + Vector( 0, 0, 55 );
			Vector vecShootDir = self.ShootAtEnemy( vecShootOrigin );
			Vector angDir = Math.VecToAngles( vecShootDir );

			Vector vecShellVelocity = g_Engine.v_right * Math.RandomFloat(40,90) + g_Engine.v_up * Math.RandomFloat(75,200) + g_Engine.v_forward * Math.RandomFloat(-40, 40);
			g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * 24, vecShellVelocity, self.pev.angles.y, m_iBrassShell, TE_BOUNCE_SHELL); 
			self.FireBullets(4, vecShootOrigin, vecShootDir, VECTOR_CONE_15DEGREES, 2048, BULLET_PLAYER_BUCKSHOT );

			int pitchShift = Math.RandomLong( 0, 20 );
			if( pitchShift > 10 )// Only shift about half the time
				pitchShift = 0;
			else
				pitchShift -= 5;

			self.SetBlending( 0, angDir.x );
			self.pev.effects = EF_MUZZLEFLASH;
			GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "weapons/sbarrel1.wav", 1, ATTN_NORM, 0, PITCH_NORM + pitchShift );

			if( self.pev.movetype != MOVETYPE_FLY && self.m_MonsterState != MONSTERSTATE_PRONE )
			{
				self.m_flAutomaticAttackTime = g_Engine.time + 0.85;
			}
	
			// UNDONE: Reload?
			--self.m_cAmmoLoaded;// take away a bullet!
		}

		//============//
		// Fire MP5	 //
		//===========//
		void FireMP5()
		{
			Math.MakeVectors( self.pev.angles );
			Vector vecShootOrigin = self.pev.origin + Vector( 0, 0, 55 );
			Vector vecShootDir = self.ShootAtEnemy( vecShootOrigin );
			Vector angDir = Math.VecToAngles( vecShootDir );

			Vector vecShellVelocity = g_Engine.v_right * Math.RandomFloat(40,90) + g_Engine.v_up * Math.RandomFloat(75,200) + g_Engine.v_forward * Math.RandomFloat(-40, 40);
			g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * 24, vecShellVelocity, self.pev.angles.y, m_iBrassShell, TE_BOUNCE_SHELL); 
			self.FireBullets(1, vecShootOrigin, vecShootDir, VECTOR_CONE_6DEGREES, 2048, BULLET_MONSTER_MP5 ); // shoot +-5 degrees

			int pitchShift = Math.RandomLong( 0, 20 );
			if( pitchShift > 10 )// Only shift about half the time
				pitchShift = 0;
			else
				pitchShift -= 5;

			self.SetBlending( 0, angDir.x );
			self.pev.effects = EF_MUZZLEFLASH;
			GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );

			switch(Math.RandomLong( 0, 1 ))
			{
				case 0:g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hgrunt/gr_mgun1.wav", 1, ATTN_NORM, 0, PITCH_NORM + pitchShift ); break;
				case 1:g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hgrunt/gr_mgun2.wav", 1, ATTN_NORM, 0, PITCH_NORM + pitchShift ); break;
			}

			if( self.pev.movetype != MOVETYPE_FLY && self.m_MonsterState != MONSTERSTATE_PRONE )
			{
				self.m_flAutomaticAttackTime = g_Engine.time + Math.RandomFloat(0.05, 0.1);
			}

			// UNDONE: Reload?
			--self.m_cAmmoLoaded;// take away a bullet!
		}

		//===========//
		// Fire Saw //
		//==========//
		void FireSaw()
		{
			Math.MakeVectors( self.pev.angles );
			Vector vecShootOrigin = self.pev.origin + Vector( 0, 0, 55 );
			Vector vecShootDir = self.ShootAtEnemy( vecShootOrigin );
			Vector angDir = Math.VecToAngles( vecShootDir );
			Vector vecShellVelocity;

			switch(Math.RandomLong( 0, 1 ))
			{
				case 0:
				{
					vecShellVelocity = g_Engine.v_right * Math.RandomFloat(75,200) + g_Engine.v_up * Math.RandomFloat(150,200) + g_Engine.v_forward * 25.0;
					g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * 6, vecShellVelocity, self.pev.angles.y, m_iSawLink, TE_BOUNCE_SHELL); 
					break;
				}
				case 1:
				{
					vecShellVelocity = g_Engine.v_right * Math.RandomFloat(100,250) + g_Engine.v_up * Math.RandomFloat(100,150) + g_Engine.v_forward * 25.0;
					g_EntityFuncs.EjectBrass( vecShootOrigin - vecShootDir * 6, vecShellVelocity, self.pev.angles.y, m_iSawLink, TE_BOUNCE_SHELL); 
					break;
				}
			}

			self.FireBullets(1, vecShootOrigin, vecShootDir, VECTOR_CONE_5DEGREES, 8192, BULLET_PLAYER_SAW, 2 ); // shoot +-5 degrees

			self.SetBlending( 0, angDir.x );
			self.pev.effects = EF_MUZZLEFLASH;
			GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );

			switch(Math.RandomLong( 0, 2 )) // originally was (0, 2)
			{
				case 0:g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hgrunt/saw_fire1.wav", 1, ATTN_NORM, 0, Math.RandomLong(0, 15) + 94 ); break;
				case 1:g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hgrunt/saw_fire2.wav", 1, ATTN_NORM, 0, Math.RandomLong(0, 15) + 94 ); break;
				case 2:g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "hgrunt/saw_fire3.wav", 1, ATTN_NORM, 0, Math.RandomLong(0, 15) + 94 ); break;
			}

			if( self.pev.movetype != MOVETYPE_FLY && self.m_MonsterState != MONSTERSTATE_PRONE )
			{
				self.m_flAutomaticAttackTime = g_Engine.time + Math.RandomFloat(0.067, 0.80);
			}

			// UNDONE: Reload?
			--self.m_cAmmoLoaded;// take away a bullet!
		}

		void CheckAmmo()
		{
			if( self.m_cAmmoLoaded <= 0 )
				self.SetConditions( bits_COND_NO_AMMO_LOADED );
		}

		//=========================================================
		// HandleAnimEvent - catches the monster-specific messages
		// that occur when tagged animation frames are played.
		//
		// Returns number of events handled, 0 if none.
		//=========================================================
		void HandleAnimEvent( MonsterEvent@ pEvent )
		{
			switch( pEvent.event )
			{
				case BARNEY_AE_SHOOT:
				{
					switch(m_iWeapon)
					{
						case 0: FirePistol(); break;
						case 2: FirePistol(); break;
						case 3: FirePython(); break;
						case 4: FireEagle(); break;
						case 5: FireShotgun(); break;
						case 6: FireMP5(); break;
						case 7: FireSaw(); break;
					}

					break;
				}
				case BARNEY_AE_DRAW:
				{
					// barney's bodygroup switches here so he can pull gun from holster
					self.pev.body = BARNEY_BODY_GUNDRAWN;
					m_bGunDrawn = true;
					break;
				}
				case BARNEY_AE_HOLSTER:
				{
					// change bodygroup to replace gun in holster
					self.pev.body = BARNEY_BODY_GUNHOLSTERED;
					m_bGunDrawn = false;
					break;
				}
				default:
					BaseClass.HandleAnimEvent( pEvent );
			}
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
			Precache();

			g_EntityFuncs.SetModel( self, "models/barney.mdl" );
			g_EntityFuncs.SetSize( self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX );

			pev.solid				= SOLID_SLIDEBOX;
			pev.movetype			= MOVETYPE_STEP;
			self.m_bloodColor		= BLOOD_COLOR_RED;
			pev.effects				= 0;
			pev.health				= 100;
			pev.view_ofs			= Vector ( 0, 0, 50 );// position of the eyes relative to monster's origin.
			self.m_flFieldOfView	= VIEW_FIELD_WIDE; // NOTE: we need a wide field of view so npc will notice player and say hello
			self.m_MonsterState		= MONSTERSTATE_NONE;
			pev.body				= 0; // gun in holster
			m_iWeapon				= 6;
			m_bGunDrawn				= false;
			self.m_afCapability		= bits_CAP_HEAR | bits_CAP_TURN_HEAD | bits_CAP_DOORS_GROUP | bits_CAP_USE_TANK;
			self.m_fCanFearCreatures 	= true; // Can attempt to run away from things like zombies
			m_flNextFearScream	= g_Engine.time;

			switch(m_iWeapon)
			{
				case 0: m_cClipSize = 17; break;
				case 2: m_cClipSize = 17; break;
				case 3: m_cClipSize = 6; break;
				case 4: m_cClipSize = 7; break;
				case 5: m_cClipSize = 8; break;
				case 6: m_cClipSize = 50; break;
				case 7: m_cClipSize = 200; break;
			}

			self.m_cAmmoLoaded		= m_cClipSize; 

			self.m_FormattedName	= "Human";

			if( self.IsPlayerAlly() )
				SetUse( UseFunction( this.FollowerUse ) );

			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
			BaseClass.Precache();	

			g_Game.PrecacheModel("models/barney.mdl");

			g_SoundSystem.PrecacheSound("barney/ba_attack1.wav" );
			g_SoundSystem.PrecacheSound("barney/ba_attack2.wav" );

			g_SoundSystem.PrecacheSound("barney/ba_pain1.wav");
			g_SoundSystem.PrecacheSound("barney/ba_pain2.wav");
			g_SoundSystem.PrecacheSound("barney/ba_pain3.wav");

			g_SoundSystem.PrecacheSound("barney/ba_die1.wav");
			g_SoundSystem.PrecacheSound("barney/ba_die2.wav");
			g_SoundSystem.PrecacheSound("barney/ba_die3.wav");
			
			g_SoundSystem.PrecacheSound("hgrunt/gr_mgun1.wav");
			g_SoundSystem.PrecacheSound("hgrunt/gr_mgun2.wav");

			g_SoundSystem.PrecacheSound("weapons/de_shot1.wav");
			g_SoundSystem.PrecacheSound("weapons/saw_fire1.wav");
			g_SoundSystem.PrecacheSound("weapons/saw_fire2.wav");
			g_SoundSystem.PrecacheSound("weapons/saw_fire3.wav");

			g_SoundSystem.PrecacheSound("weapons/sbarrel1.wav");
			g_SoundSystem.PrecacheSound("weapons/357_shot1.wav");

			m_iBrassShell = g_Game.PrecacheModel("models/shell.mdl");
			m_iShotgunShell = g_Game.PrecacheModel("models/shotgunshell.mdl"); 
			m_iSawLink = g_Game.PrecacheModel("models/saw_link.mdl");
			m_iSawShell = g_Game.PrecacheModel("models/saw_shell.mdl");
		}

		void FearScream()
		{
			if( m_flNextFearScream < g_Engine.time )
			{
				switch (Math.RandomLong(0,2))
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/down.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/aghh.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
					case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/hey.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
				}

				m_flNextFearScream = g_Engine.time + Math.RandomLong(2,5);
			}
		}
		
		void PainSound()
		{
			if(g_Engine.time < m_flpainTime)
				return;
			
			m_flpainTime = g_Engine.time + Math.RandomFloat(0.5, 0.75);
			switch (Math.RandomLong(0,2))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/ba_pain1.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/ba_pain2.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/ba_pain3.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
			}
		}
		
		void DeathSound()
		{
			switch (Math.RandomLong(0,2))
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/ba_die1.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/ba_die2.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "barney/ba_die3.wav", 1, ATTN_NORM, 0, PITCH_NORM); break;
			}
		}

		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
		{	
			if( pevAttacker is null )
				return 0;

			CBaseEntity@ pAttacker = g_EntityFuncs.Instance( pevAttacker );

			if( self.CheckAttacker( pAttacker ) )
				return 0;

			// make sure friends talk about it if player hurts talkmonsters...
			int ret = BaseClass.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);
			if( ( !self.IsAlive() || self.pev.deadflag == DEAD_DYING) && (!self.IsPlayerAlly()))	// evils dont alert friends!
				return ret;

			if( self.m_MonsterState != MONSTERSTATE_PRONE && (pevAttacker.flags & FL_CLIENT) != 0 )
			{
				// This is a heurstic to determine if the player intended to harm me
				// If I have an enemy, we can't establish intent (may just be crossfire)
				if( !self.m_hEnemy.IsValid() )
				{		
					if( self.pev.deadflag == DEAD_NO )
					{
						// If the player was facing directly at me, or I'm already suspicious, get mad
						if( (self.m_afMemory & bits_MEMORY_SUSPICIOUS) != 0 || pAttacker.IsFacing( self.pev, 0.96f ) )
						{
							// Alright, now I'm pissed!
							//PlaySentence( "BA_MAD", 4, VOL_NORM, ATTN_NORM );

							self.Remember( bits_MEMORY_PROVOKED );
							self.StopPlayerFollowing( true, false );
						}
						else
						{
							// Hey, be careful with that
							//PlaySentence( "BA_SHOT", 4, VOL_NORM, ATTN_NORM );
							self.Remember( bits_MEMORY_SUSPICIOUS );
						}
					}
				}
				else if( (!self.m_hEnemy.GetEntity().IsPlayer()) && self.pev.deadflag == DEAD_NO )
				{
					//PlaySentence( "BA_SHOT", 4, VOL_NORM, ATTN_NORM );
				}
			}

			return ret;
		}

		void TraceAttack( entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType)
		{
			if (bitsDamageType & DMG_SHOCK != 0)
				return;

			BaseClass.TraceAttack( pevAttacker, flDamage, vecDir, ptr, bitsDamageType );
		}

		Schedule@ GetScheduleOfType( int Type )
		{		
			Schedule@ psched;

			switch( Type )
			{
			case SCHED_ARM_WEAPON:
				if( self.m_hEnemy.IsValid() )
					return slBarneyEnemyDraw;// face enemy, then draw.
				break;

			// Hook these to make a looping schedule
			case SCHED_TARGET_FACE:
				// call base class default so that barney will talk
				// when 'used' 
				@psched = BaseClass.GetScheduleOfType( Type );
				
				if( psched is Schedules::slIdleStand )
					return slBaFaceTarget;	// override this for different target face behavior
				else
					return psched;


			case SCHED_RELOAD:
				return slBaReloadQuick; //Immediately reload.

			case SCHED_BARNEY_RELOAD:
				return slBaReload;

			case SCHED_TARGET_CHASE:
				return slBaFollow;

			case SCHED_IDLE_STAND:
				// call base class default so that scientist will talk
				// when standing during idle
				@psched = BaseClass.GetScheduleOfType( Type );

				if( psched is Schedules::slIdleStand )		
					return slIdleBaStand;// just look straight ahead.
				else
					return psched;
			}

			return BaseClass.GetScheduleOfType( Type );
		}
		
		Schedule@ GetSchedule()
		{
			if( self.HasConditions( bits_COND_HEAR_SOUND ) )
			{
				CSound@ pSound = self.PBestSound();

				if( pSound !is null && (pSound.m_iType & bits_SOUND_DANGER) != 0 )
				{
					//FearScream(); //AGHH!!!!
					return self.GetScheduleOfType( SCHED_TAKE_COVER_FROM_BEST_SOUND );
				}
			}

			if( self.HasConditions( bits_COND_ENEMY_DEAD ) )
				self.PlaySentence( "BA_KILL", 4, VOL_NORM, ATTN_NORM );

			switch( self.m_MonsterState )
			{
			case MONSTERSTATE_COMBAT:
				{
					// dead enemy
					if( self.HasConditions( bits_COND_ENEMY_DEAD ) )				
						return BaseClass.GetSchedule();// call base class, all code to handle dead enemies is centralized there.

					// always act surprized with a new enemy
					if( self.HasConditions( bits_COND_NEW_ENEMY ) && self.HasConditions( bits_COND_LIGHT_DAMAGE) )
						return self.GetScheduleOfType( SCHED_SMALL_FLINCH );
						
					// wait for one schedule to draw gun
					if( !m_bGunDrawn )
						return self.GetScheduleOfType( SCHED_ARM_WEAPON );

					if( self.HasConditions( bits_COND_HEAVY_DAMAGE ) )
						return self.GetScheduleOfType( SCHED_TAKE_COVER_FROM_ENEMY );
					
					//Barney reloads now.
					if( self.HasConditions ( bits_COND_NO_AMMO_LOADED ) )
						return self.GetScheduleOfType ( SCHED_BARNEY_RELOAD );
				}
				break;

			case MONSTERSTATE_IDLE:
					//Barney reloads now.
					if( self.m_cAmmoLoaded != m_cClipSize )
						return self.GetScheduleOfType( SCHED_BARNEY_RELOAD );

			case MONSTERSTATE_ALERT:	
				{
					if( self.HasConditions(bits_COND_LIGHT_DAMAGE | bits_COND_HEAVY_DAMAGE) )
						return self.GetScheduleOfType( SCHED_SMALL_FLINCH ); // flinch if hurt

					//The player might have just +used us, immediately follow and dis-regard enemies.
					//This state gets set (alert) when the monster gets +used
					if( (!self.m_hEnemy.IsValid() || !self.HasConditions( bits_COND_SEE_ENEMY)) && self.IsPlayerFollowing() )	//Start Player Following
					{
						if( !self.m_hTargetEnt.GetEntity().IsAlive() )
						{
							self.StopPlayerFollowing( false, false );// UNDONE: Comment about the recently dead player here?
							break;
						}
						else
						{
								
							return self.GetScheduleOfType( SCHED_TARGET_FACE );
						}
					}
				}
				break;
			}
			
			return BaseClass.GetSchedule();
		}
		
		void FollowerUse( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
		{
			self.FollowerPlayerUse( pActivator, pCaller, useType, flValue );
			
			CBaseEntity@ pTarget = self.m_hTargetEnt;
			
			if( pTarget is pActivator )
			{
				g_SoundSystem.PlaySentenceGroup( self.edict(), "BA_OK", 1.0, ATTN_NORM, 0, PITCH_NORM );
			}
			else
				g_SoundSystem.PlaySentenceGroup( self.edict(), "BA_WAIT", 1.0, ATTN_NORM, 0, PITCH_NORM );
		}
	}

	array<ScriptSchedule@>@ monster_human_schedules;

	ScriptSchedule slBaFollow( 
		bits_COND_NEW_ENEMY		|
		bits_COND_LIGHT_DAMAGE	|
		bits_COND_HEAVY_DAMAGE	|
		bits_COND_HEAR_SOUND,
		bits_SOUND_DANGER, 
		"Follow" );
			
	ScriptSchedule slBaFaceTarget(
		//bits_COND_CLIENT_PUSH	|
		bits_COND_NEW_ENEMY		|
		bits_COND_LIGHT_DAMAGE	|
		bits_COND_HEAVY_DAMAGE	|
		bits_COND_HEAR_SOUND ,
		bits_SOUND_DANGER,
		"FaceTarget" );
		
	ScriptSchedule slIdleBaStand(
		bits_COND_NEW_ENEMY		|
		bits_COND_LIGHT_DAMAGE	|
		bits_COND_HEAVY_DAMAGE	|
		bits_COND_HEAR_SOUND	|
		bits_COND_SMELL,

		bits_SOUND_COMBAT		|// sound flags - change these, and you'll break the talking code.	
		bits_SOUND_DANGER		|
		bits_SOUND_MEAT			|// scents
		bits_SOUND_CARCASS		|
		bits_SOUND_GARBAGE,
		"IdleStand" );
		
	ScriptSchedule slBaReload(
		bits_COND_HEAVY_DAMAGE	|
		bits_COND_HEAR_SOUND,
		bits_SOUND_DANGER,
		"Barney Reload");
		
	ScriptSchedule slBaReloadQuick(
		bits_COND_HEAVY_DAMAGE	|
		bits_COND_HEAR_SOUND,
		bits_SOUND_DANGER,
		"Barney Reload Quick");
			
	ScriptSchedule slBarneyEnemyDraw( 0, 0, "Barney Enemy Draw" );

	void InitSchedules()
	{
			
		slBaFollow.AddTask( ScriptTask(TASK_MOVE_TO_TARGET_RANGE, 128.0f) );
		slBaFollow.AddTask( ScriptTask(TASK_SET_SCHEDULE, SCHED_TARGET_FACE) );
		
		slBarneyEnemyDraw.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slBarneyEnemyDraw.AddTask( ScriptTask(TASK_FACE_ENEMY) );
		slBarneyEnemyDraw.AddTask( ScriptTask(TASK_PLAY_SEQUENCE_FACE_ENEMY, float(ACT_ARM)) );
			
		slBaFaceTarget.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );
		slBaFaceTarget.AddTask( ScriptTask(TASK_FACE_TARGET) );
		slBaFaceTarget.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );
		slBaFaceTarget.AddTask( ScriptTask(TASK_SET_SCHEDULE, float(SCHED_TARGET_CHASE)) );
			
		slIdleBaStand.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slIdleBaStand.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );
		slIdleBaStand.AddTask( ScriptTask(TASK_WAIT, 2) );
		//slIdleBaStand.AddTask( ScriptTask(TASK_TLK_HEADRESET) );
			
		slBaReload.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slBaReload.AddTask( ScriptTask(TASK_SET_FAIL_SCHEDULE, float(SCHED_RELOAD)) );
		slBaReload.AddTask( ScriptTask(TASK_FIND_COVER_FROM_ENEMY) );
		slBaReload.AddTask( ScriptTask(TASK_RUN_PATH) );
		slBaReload.AddTask( ScriptTask(TASK_REMEMBER, float(bits_MEMORY_INCOVER)) );
		slBaReload.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT_ENEMY_OCCLUDED) );
		slBaReload.AddTask( ScriptTask(TASK_RELOAD) );
		slBaReload.AddTask( ScriptTask(TASK_FACE_ENEMY) );
				
		slBaReloadQuick.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slBaReloadQuick.AddTask( ScriptTask(TASK_RELOAD) );
		slBaReloadQuick.AddTask( ScriptTask(TASK_FACE_ENEMY) );
		
		array<ScriptSchedule@> scheds = {slBaFollow, slBarneyEnemyDraw, slBaFaceTarget, slIdleBaStand, slBaReload, slBaReloadQuick};
		
		@monster_human_schedules = @scheds;
	}

	enum monsterScheds
	{
		SCHED_BARNEY_RELOAD = LAST_COMMON_SCHEDULE + 1,
	}

	void Register()
	{
		InitSchedules();
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterHuman::CHuman", "npc_human");
	}
}