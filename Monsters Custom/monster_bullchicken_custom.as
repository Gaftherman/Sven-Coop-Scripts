//
// Author: Gaftherman
// Taken and ported from: https://github.com/SamVanheer/halflife-updated/blob/master/dlls/bullsquid.cpp
//
// ===================================
//
// This doesn't include anything new or innovative, it's simply the original Half-Life BullSquid ported to AngelScript.
//
// Some bugs that I couldn't fix (mb for my low knowledge in AS):
//
// - The "BSQUID_AE_HOP" animation (when some player / ally damages the bullsquid without it realizing it)
// is disabled because it stays in an 'infinite' Loop (sometimes it stops doing the jump but it is very rare).
// If you want to enable and view it, go to line 1121 and remove the //.
// 
// - Inside TakeDamage there are certain variables like "FTriangulate" and "InsertWaypoint" that are not in AS 
// (or so I think) and I don't know if there is another way to change it for a similar one.
//
// - What the heck is fabs? line 293
//
// - FValidateHintType, I'm 80% sure it's not in AS but I put it the same way.
//
// - For some reason it doesn't go to the bodies of dead players.
//
// Usage: In your map script include this
//	#include "../monster_bullchicken_custom"
// and in your MapInit() {...}
//	"MonsterBullCustom::Register();"
//
// ===================================
//
// If you want to modify it or use it as a base for some monster, you are free to use it always giving credits.
//

namespace MonsterBullCustom
{
	//=========================================================
	// Monster's Anim Events Go Here
	//=========================================================
	const int BSQUID_AE_SPIT 		= 1;
	const int BSQUID_AE_BITE 		= 2;
	const int BSQUID_AE_BLINK 		= 3;
	const int BSQUID_AE_TAILWHIP 	= 4;
	const int BSQUID_AE_HOP 		= 5;
	const int BSQUID_AE_THROW 		= 6;

	const int SQUID_SPRINT_DIST		= 256; // How close the squid has to get before starting to sprint and refusing to swerve

	const int TASKSTATUS_RUNNING 	= 1; // Running task & movement
	const int TASKSTATUS_COMPLETE 	= 4; // Completed, get next task

	const int BULL_HEALTH 			= int(g_EngineFuncs.CVarGetFloat( "sk_bullsquid_health" ));
	const int BULL_DAMAGE_BIT 		= int(g_EngineFuncs.CVarGetFloat( "sk_bullsquid_dmg_bite" ));
	const int BULL_DAMAGE_SPIT 		= int(g_EngineFuncs.CVarGetFloat( "sk_bullsquid_dmg_spit" ));
	const int BULL_DAMAGE_WHIP 		= int(g_EngineFuncs.CVarGetFloat( "sk_bullsquid_dmg_whip" ));

	CBaseEntity@ CheckTraceHullAttack( CBaseMonster@ pThis, float flDist, int iDamage, int iDmgType ) 
	{
		TraceResult tr;

		if(pThis.IsPlayer()) 
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
		
		if( tr.pHit !is null ) 
		{
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );
			if( iDamage > 0 ) 
			{
				pEntity.TakeDamage( pThis.pev, pThis.pev, iDamage, iDmgType );
			}
			return pEntity;
		}
		return null;
	}

	class CSquidSpit : ScriptBaseMonsterEntity
	{	
		private int iSquidSpitSprite;
		private int m_maxFrame;

		void Spawn()
		{
			Precache();
			
			self.pev.movetype 	= MOVETYPE_FLY;
			self.pev.solid 		= SOLID_BBOX;
			self.pev.rendermode = kRenderTransAlpha;
			self.pev.renderamt	= 255;
			self.pev.frame 		= 0;
			self.pev.scale 		= 0.5;
			self.pev.animtime 	= g_Engine.time;
			self.pev.frame 		= 0;
			self.pev.dmg 		= BULL_DAMAGE_SPIT;

			SetTouch( TouchFunction( SquidTouch ) );

			g_EntityFuncs.SetModel( self, "sprites/bigspit.spr");
			g_EntityFuncs.SetSize( self.pev, Vector( 0, 0, 0), Vector(0, 0, 0) );

			self.pev.nextthink = g_Engine.time + 0.1;

		}

		void Precache()
		{
			iSquidSpitSprite = g_Game.PrecacheModel("sprites/tinyspit.spr");

			g_Game.PrecacheModel( "sprites/bigspit.spr" );
		}
		
		void SquidTouch( CBaseEntity@ pOther )
		{
			SetTouch( null );

			TraceResult tr;
			int	iPitch;

			iPitch = Math.RandomLong( 90, 110 );

			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_acid1.wav", 1, ATTN_NORM, 0, iPitch );	

			switch( Math.RandomLong( 0, 1 ) )
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "bullchicken/bc_spithit1.wav", 1, ATTN_NORM, 0, iPitch );	
				break;

				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "bullchicken/bc_spithit2.wav", 1, ATTN_NORM, 0, iPitch );
				break;
			}

			if( pOther.pev.takedamage != 0 )
			{
				pOther.TakeDamage( self.pev, self.pev.owner.vars, self.pev.dmg, DMG_GENERIC );
			}
			else
			{
				// make a splat on the wall
				g_Utility.TraceLine( self.pev.origin, self.pev.origin + self.pev.velocity * 10, dont_ignore_monsters, self.edict(), tr);
				g_Utility.DecalTrace( tr, DECAL_SPIT1 + Math.RandomLong(0,1));
				
				// make some flecks
				NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, tr.vecEndPos );
					message.WriteByte(TE_SPRITE_SPRAY);
					message.WriteCoord(tr.vecEndPos.x); // pos
					message.WriteCoord(tr.vecEndPos.y);	
					message.WriteCoord(tr.vecEndPos.z);	
					message.WriteCoord( tr.vecPlaneNormal.x);	// dir
					message.WriteCoord( tr.vecPlaneNormal.y);	
					message.WriteCoord( tr.vecPlaneNormal.z);	
					message.WriteShort( iSquidSpitSprite );	// model
					message.WriteByte( 5 );	 // count
					message.WriteByte( 30 ); // speed
					message.WriteByte( 80 ); // noise ( client will divide by 100 )
				message.End();
			}

			g_EntityFuncs.Remove( self );
			self.pev.nextthink = g_Engine.time + 0.1;
		}
	}

	CSquidSpit@ ShootSquid(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity)
	{
		CBaseEntity@ pre_pSquid = g_EntityFuncs.CreateEntity( "proj_squidpit", null, false);
		CSquidSpit@ pSquid = cast<CSquidSpit@>(CastToScriptClass(pre_pSquid));

		pSquid.Spawn();

		g_EntityFuncs.SetOrigin(pSquid.self, vecStart );
		pSquid.pev.velocity = vecVelocity;

		return pSquid;
	}

	class CBullCustom : ScriptBaseMonsterEntity
	{
		private bool m_fCanThreatDisplay;// this is so the squid only does the "I see a headcrab!" dance one time. 
		private int iSquidSpitSprite;
		private float m_flLastHurtTime;// we keep track of this, because ifsomething hurts a squid, it will forget about its love of headcrabs for a while.
		private float m_flNextSpitTime;// last time the bullsquid used the spit attack.

		CBullCustom()
		{
			@this.m_Schedules = @CBullchedules;
		}

		//=========================================================
		// IgnoreConditions 
		//=========================================================
		int IgnoreConditions()
		{
			int iIgnore = 0;

			if( g_Engine.time - m_flLastHurtTime <= 20 )
			{
				// Haven't been hurt in 20 seconds, so let the squid care about stink. 
				iIgnore = bits_COND_SMELL | bits_COND_SMELL_FOOD;
			}

			if( self.m_hEnemy.GetEntity() !is null )
			{
				if( self.m_hEnemy.GetEntity().pev.ClassNameIs( "monster_headcrab" ) )
				{
					// (Unless after a tasty headcrab)
					iIgnore = bits_COND_SMELL | bits_COND_SMELL_FOOD;
				}
			}

			return iIgnore;
		}

		//=========================================================
		// IRelationship - overridden for bullsquid so that it can
		// be made to ignore its love of headcrabs for a while.
		//=========================================================
		int IRelationship( CBaseEntity@ pTarget )
		{
			if( g_Engine.time - m_flLastHurtTime < 5 && pTarget.pev.ClassNameIs( "monster_headcrab" ) )
			{
				// ifsquid has been hurt in the last 5 seconds, and is getting relationship for a headcrab, 
				// tell squid to disregard crab. 
				return R_NO;
			}

			return self.IRelationship( pTarget );
		}

		//=========================================================
		// TakeDamage - overridden for bullsquid so we can keep track
		// of how much time has passed since it was last injured
		//=========================================================
		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
		{
			CBaseEntity@ pAttacker = g_EntityFuncs.Instance( pevAttacker );

			/*float flDist;
			Vector vecApex;

			// If the squid is running, has an enemy, was hurt by the enemy, hasn't been hurt in the last 3 seconds, and isn't too close to the enemy,
			// it will swerve. (whew).
			if( self.m_hEnemy.GetEntity() !is null && self.IsMoving() && pAttacker == self.m_hEnemy.GetEntity() && g_Engine.time - m_flLastHurtTime > 3 )
			{
				flDist = ( self.pev.origin - self.m_hEnemy.GetEntity().pev.origin ).Length2D();
				
				if( flDist > SQUID_SPRINT_DIST )
				{
					flDist = ( self.pev.origin - self.m_Route[ self.m_iRouteIndex ].vecLocation ).Length2D();// reusing flDist. 

					if( self.FTriangulate( self.pev.origin, self.m_Route[ self.m_iRouteIndex ].vecLocation, flDist * 0.5, m_hEnemy, vecApex ) )
					{
						self.InsertWaypoint( vecApex, bits_MF_TO_DETOUR | bits_MF_DONT_SIMPLIFY );
					}
				}
			}*/

			if( !pAttacker.pev.ClassNameIs( "monster_headcrab" ) )
			{
				// don't forget about headcrabs ifit was a headcrab that hurt the squid.
				m_flLastHurtTime = g_Engine.time;
			}

			return BaseClass.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);
		}

		//=========================================================
		// CheckRangeAttack1
		//=========================================================
		bool CheckRangeAttack1( float flDot, float flDist )
		{
			if( self.IsMoving() && flDist >= 512 )
			{
				// Squid will far too far behind ifhe stops running to spit at this distance from the enemy.
				return false;
			}

			if( flDist > 64 && flDist <= 784 && flDot >= 0.5 && g_Engine.time >= m_flNextSpitTime )
			{
				if( self.m_hEnemy.GetEntity() is null )
				{
					if( /* fabs */ (self.pev.origin.z - self.m_hEnemy.GetEntity().pev.origin.z) > 256 )
					{
						// Don't try to spit at someone up really high or down really low.
						return false;
					}   // What the hell is fabs?
				}

				if( self.IsMoving() )
				{
					// Don't spit again for a long time, resume chasing enemy.
					m_flNextSpitTime = g_Engine.time + 5;
				}
				else
				{
					// Not moving, so spit again pretty soon.
					m_flNextSpitTime = g_Engine.time + 0.5;
				}

				return true;
			}

			return false;
		}

		//=========================================================
		// CheckMeleeAttack1 - bullsquid is a big guy, so has a longer
		// melee range than most monsters. This is the tailwhip attack
		//=========================================================
		bool CheckMeleeAttack1( float flDot, float flDist )
		{
			if( self.m_hEnemy.GetEntity().pev.health <= BULL_DAMAGE_WHIP &&  flDist <= 85 && flDot >= 0.7 || flDist <= 35 && flDot >= 0.7 )
			{
				return true;
			}
			return false;
		}

		//=========================================================
		// CheckMeleeAttack2 - bullsquid is a big guy, so has a longer
		// melee range than most monsters. This is the bite attack.
		// this attack will not be performed ifthe tailwhip attack
		// is valid.
		//=========================================================
		bool CheckMeleeAttack2( float flDot, float flDist )
		{
			if( flDist <= 85 && flDot >= 0.7 && !self.HasConditions( bits_COND_CAN_MELEE_ATTACK1 ) )		// The player & bullsquid can be as much as their bboxes 
			{										// apart (48 * sqrt(3)) and he can still attack (85 is a little more than 48*sqrt(3))
				return true;
			}
			return false;
		}  

		//=========================================================
		//  FValidateHintType 
		//=========================================================
		/*bool FValidateHintType( short sHint )
		{
			int i;

			static short sSquidHints[] =
			{
				HINT_WORLD_HUMAN_BLOOD,
			};

			for ( i = 0 ; i < ARRAYSIZE ( sSquidHints ) ; i++ )
			{
				if( sSquidHints[ i ] == sHint )
				{
					return true;
				}
			}

			//ALERT ( at_aiconsole, "Couldn't validate hint type" );
			return false;
		}*/

		//=========================================================
		// ISoundMask - returns a bit mask indicating which types
		// of sounds this monster regards. In the base class implementation,
		// monsters care about all sounds, but no scents.
		//=========================================================
		int ISoundMask()
		{
			return	
			bits_SOUND_WORLD	|		
			bits_SOUND_COMBAT	|
			bits_SOUND_CARCASS	|
			bits_SOUND_MEAT		|
			bits_SOUND_GARBAGE	|
			bits_SOUND_PLAYER;
		}

		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return self.GetClassification( CLASS_ALIEN_PREDATOR );
		}

		//=========================================================
		// IdleSound 
		//=========================================================
		void IdleSound()
		{
			switch( Math.RandomLong( 0, 4 ) )
			{
				case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_idle1.wav", 1, 1.5 );
				break;

				case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_idle2.wav", 1, 1.5 );	
				break;

				case 2: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_idle3.wav", 1, 1.5 );
				break;

				case 3: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_idle4.wav", 1, 1.5 );
				break;

				case 4: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_idle5.wav", 1, 1.5 );	
				break;
			}
		}

		//=========================================================
		// PainSound 
		//=========================================================
		void PainSound()
		{
			int iPitch = Math.RandomLong( 85, 120 );

			switch( Math.RandomLong( 0, 3 ) )
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_pain1.wav", 1, ATTN_NORM, 0, iPitch );	
				break;

				case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_pain2.wav", 1, ATTN_NORM, 0, iPitch );
				break;

				case 2:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_pain3.wav", 1, ATTN_NORM, 0, iPitch );
				break;

				case 3:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_pain4.wav", 1, ATTN_NORM, 0, iPitch );
				break;
			}
		}

		//=========================================================
		// AlertSound
		//=========================================================
		void AlertSound()
		{
			int iPitch = Math.RandomLong( 140, 160 );

			switch( Math.RandomLong( 0, 1 ) )
			{
				case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_idle1.wav", 1, ATTN_NORM, 0, iPitch );				
				break;

				case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "bullchicken/bc_idle2.wav", 1, ATTN_NORM, 0, iPitch );	
				break;
			}
		}

		//=========================================================
		// SetYawSpeed - allows each sequence to have a different
		// turn rate associated with it.
		//=========================================================
		void SetYawSpeed()
		{
			int ys;

			ys = 0;

			switch( self.m_Activity )
			{
				case ACT_WALK:			ys = 90;	break;
				case ACT_RUN:			ys = 90;	break;
				case ACT_IDLE:			ys = 90;	break;
				case ACT_RANGE_ATTACK1:	ys = 90;	break;

				default: 				ys = 90; 	break;
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
				case BSQUID_AE_SPIT:
				{
					if(self.m_hEnemy.GetEntity() !is null)
					{
						Vector	vecSpitOffset;
						Vector	vecSpitDir;

						Math.MakeVectors( self.pev.angles );

						// !!!HACKHACK - the spot at which the spit originates (in front of the mouth) was measured in 3ds and hardcoded here.
						// we should be able to read the position of bones at runtime for this info.
						vecSpitOffset = ( g_Engine.v_right * 8 + g_Engine.v_forward * 37 + g_Engine.v_up * 23 );		
						vecSpitOffset = ( self.pev.origin + vecSpitOffset );
						vecSpitDir = ( ( self.m_hEnemy.GetEntity().pev.origin + self.m_hEnemy.GetEntity().pev.view_ofs ) - vecSpitOffset ).Normalize();

						vecSpitDir.x += Math.RandomFloat( -0.05, 0.05 );
						vecSpitDir.y += Math.RandomFloat( -0.05, 0.05 );
						vecSpitDir.z += Math.RandomFloat( -0.05, 0 );

						// Do stuff for this event.
						AttackSound();

						// Spew the spittle temporary ents.
						NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSpitOffset );
							message.WriteByte(TE_SPRITE_SPRAY);
							message.WriteCoord(vecSpitOffset.x); // pos
							message.WriteCoord(vecSpitOffset.y);	
							message.WriteCoord(vecSpitOffset.z);	
							message.WriteCoord( vecSpitDir.x); // dir
							message.WriteCoord( vecSpitDir.y);	
							message.WriteCoord( vecSpitDir.z);	
							message.WriteShort( iSquidSpitSprite ); // model
							message.WriteByte( 15 ); // count
							message.WriteByte( 210 ); // speed
							message.WriteByte( 25 ); // noise ( client will divide by 100 )
						message.End();

						//CSquidSpit::Shoot( pev, vecSpitOffset, vecSpitDir * 900 );

						CSquidSpit@ pSquid = ShootSquid( self.pev, vecSpitOffset + g_Engine.v_forward * 8, vecSpitDir * 1600 );

						@pSquid.pev.owner = self.edict();
					}
				}
				break;
				
				case BSQUID_AE_BITE:
				{
					// SOUND HERE!
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, BULL_DAMAGE_BIT, DMG_SLASH );
					if( pHurt !is null )
					{
						// pHurt.pev.punchangle.z = -15;
						// pHurt.pev.punchangle.x = -45;
						pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_forward * 100;
						pHurt.pev.velocity = pHurt.pev.velocity + g_Engine.v_up * 100;
					}
				}
				break;

				case BSQUID_AE_TAILWHIP:
				{
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, BULL_DAMAGE_WHIP, DMG_CLUB | DMG_ALWAYSGIB );
					if( pHurt !is null )
					{
						pHurt.pev.punchangle.z = -20;
						pHurt.pev.punchangle.x = 20;
						pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_forward * 100;
						pHurt.pev.velocity = pHurt.pev.velocity + g_Engine.v_up * 100;
					}
				}
				break;

				case BSQUID_AE_BLINK:
				{
					// Close eye. 
					self.pev.skin = 1;
				}
				break;
				
				case BSQUID_AE_HOP:
				{
					float flGravity = g_EngineFuncs.CVarGetFloat( "sv_gravity" );

					if ( self.pev.FlagBitSet(FL_ONGROUND) )
					{
						self.pev.movetype = MOVETYPE_TOSS;
						self.pev.flags &= ~FL_ONGROUND;
					}

					// jump into air for 0.8 (24/30) seconds
					// self.pev.velocity.z += (0.875 * flGravity) * 0.5;
					self.pev.velocity.z += (0.625 * flGravity) * 0.5;
				}
				break;

				case BSQUID_AE_THROW:
				{
					int iPitch;

					// squid throws its prey ifthe prey is a client. 
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, 0, 0 );
						
					if( pHurt !is null )
					{
						// croonchy bite sound
						switch(  Math.RandomLong( 0, 1 ) )
						{
							case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "bullchicken/bc_bite2.wav", 1, ATTN_NORM, 0, Math.RandomLong( 90, 110 ));
							break;

							case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, "bullchicken/bc_bite3.wav", 1, ATTN_NORM, 0, Math.RandomLong( 90, 110 ));	
							break;
						}
							
						// pHurt.pev.punchangle.x =  Math.RandomLong(0,34) - 5;
						// pHurt.pev.punchangle.z =  Math.RandomLong(0,49) - 25;
						// pHurt.pev.punchangle.y =  Math.RandomLong(0,89) - 45;
				
						// Screeshake transforms the viewmodel as well as the viewangle. No problems with seeing the ends of the viewmodels.
						g_PlayerFuncs.ScreenShake( pHurt.pev.origin, 25, 1.5, 0.7, 2 );

						if( pHurt.IsPlayer() )
						{
							Math.MakeVectors( self.pev.angles );
							pHurt.pev.velocity = pHurt.pev.velocity + g_Engine.v_forward * 300 + g_Engine.v_up * 300;
						}
					}
				}
				break;

				default: BaseClass.HandleAnimEvent( pEvent );
			}
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
			Precache();

			g_EntityFuncs.SetModel( self, "models/bullsquid.mdl");
			g_EntityFuncs.SetSize( self.pev, Vector( -32, -32, 0 ), Vector( 32, 32, 64 ) );

			self.pev.solid			= SOLID_SLIDEBOX;
			self.pev.movetype		= MOVETYPE_STEP;
			self.m_bloodColor		= BLOOD_COLOR_GREEN;
			self.pev.effects		= 0;
			self.pev.health			= BULL_HEALTH;
			self.m_flFieldOfView	= 0.2;// indicates the width of this monster's forward view cone ( as a dotproduct result )
			self.m_MonsterState		= MONSTERSTATE_NONE;

			self.m_FormattedName	= "Bull Squid";

			m_fCanThreatDisplay		= true;
			m_flNextSpitTime 		= g_Engine.time;

			self.MonsterInit();
		}

		//=========================================================
		// Precache - precaches all resources this monster needs
		//=========================================================
		void Precache()
		{
			iSquidSpitSprite = g_Game.PrecacheModel("sprites/tinyspit.spr");

			g_Game.PrecacheModel( "sprites/bigspit.spr" );;// spit projectile.
			g_Game.PrecacheModel("models/bullsquid.mdl");

			g_SoundSystem.PrecacheSound("zombie/claw_miss2.wav");// because we use the basemonster SWIPE animation event

			g_SoundSystem.PrecacheSound("bullchicken/bc_attack2.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_attack3.wav");
			
			g_SoundSystem.PrecacheSound("bullchicken/bc_die1.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_die2.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_die3.wav");
			
			g_SoundSystem.PrecacheSound("bullchicken/bc_idle1.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_idle2.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_idle3.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_idle4.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_idle5.wav");
			
			g_SoundSystem.PrecacheSound("bullchicken/bc_pain1.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_pain2.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_pain3.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_pain4.wav");
			
			g_SoundSystem.PrecacheSound("bullchicken/bc_attackgrowl.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_attackgrowl2.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_attackgrowl3.wav");

			g_SoundSystem.PrecacheSound("bullchicken/bc_acid1.wav");

			g_SoundSystem.PrecacheSound("bullchicken/bc_bite2.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_bite3.wav");

			g_SoundSystem.PrecacheSound("bullchicken/bc_spithit1.wav");
			g_SoundSystem.PrecacheSound("bullchicken/bc_spithit2.wav");
		}

		//=========================================================
		// DeathSound
		//=========================================================
		void DeathSound()
		{
			switch( Math.RandomLong(0,2) )
			{
				case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_die1.wav", 1, ATTN_NORM );	
				break;

				case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_die2.wav", 1, ATTN_NORM );	
				break;

				case 2: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_die3.wav", 1, ATTN_NORM );	
				break;
			}
		}

		//=========================================================
		// AttackSound
		//=========================================================
		void AttackSound()
		{
			switch( Math.RandomLong(0,1) )
			{
				case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_WEAPON, "bullchicken/bc_attack2.wav", 1, ATTN_NORM );	
				break;

				case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_WEAPON, "bullchicken/bc_attack3.wav", 1, ATTN_NORM );	
				break;
			}
		}

		//========================================================
		// RunAI - overridden for bullsquid because there are things
		// that need to be checked every think.
		//========================================================
		void RunAI()
		{
			// first, do base class stuff
			BaseClass.RunAI();

			if( self.pev.skin != 0 )
			{
				// close eye ifit was open.
				self.pev.skin = 0; 
			}

			if( Math.RandomLong(0,39) == 0 )
			{
				self.pev.skin = 1;
			}

			if( self.m_hEnemy.GetEntity() is null && self.m_Activity == ACT_RUN )
			{
				// chasing enemy. Sprint for last bit
				if( (self.pev.origin - self.m_hEnemy.GetEntity().pev.origin).Length2D() < SQUID_SPRINT_DIST )
				{
					self.pev.framerate = 1.25;
				}
			}	
		}

		//=========================================================
		// GetSchedule 
		//=========================================================
		Schedule@ GetSchedule( void )
		{
			switch( self.m_MonsterState )
			{
				case MONSTERSTATE_ALERT:
				{
					if( self.HasConditions(bits_COND_LIGHT_DAMAGE | bits_COND_HEAVY_DAMAGE) )
					{
						return GetScheduleOfType( SCHED_SQUID_HURTHOP );
					}

					if( self.HasConditions(bits_COND_SMELL_FOOD) )
					{
						CSound@ pSound;
						@pSound = self.PBestSound();
						
						if( pSound !is null && (!self.FInViewCone ( pSound.m_vecOrigin ) || !self.FVisible ( pSound.m_vecOrigin )) )
						{
							// Scent is behind or occluded
							return GetScheduleOfType( SCHED_SQUID_SNIFF_AND_EAT );
						}

						// Food is right out in the open. Just go get it.
						return GetScheduleOfType( SCHED_SQUID_EAT );
					}
					
					if( self.HasConditions(bits_COND_SMELL) )
					{
						// There's something stinky. 
						CSound@ pSound;
						@pSound = self.PBestSound();

						if( pSound !is null )
							return GetScheduleOfType( SCHED_SQUID_WALLOW);
					}

					break;
				}
				case MONSTERSTATE_COMBAT:
				{
					// Dead enemy
					if( self.HasConditions( bits_COND_ENEMY_DEAD ) )
					{
						// Call base class, all code to handle dead enemies is centralized there.
						return BaseClass.GetSchedule();
					}

					if( self.HasConditions(bits_COND_NEW_ENEMY) )
					{
						if( m_fCanThreatDisplay && self.IRelationship( self.m_hEnemy.GetEntity() ) == R_HT )
						{
							// This means squid sees a headcrab!
							m_fCanThreatDisplay = false; // Only do the headcrab dance once per lifetime.
							return GetScheduleOfType( SCHED_SQUID_SEECRAB );
						}
						else
						{
							return GetScheduleOfType( SCHED_WAKE_ANGRY );
						}
					}

					if( self.HasConditions(bits_COND_SMELL_FOOD) )
					{
						CSound@ pSound;
						@pSound = self.PBestSound();
						
						if( pSound !is null && (!self.FInViewCone ( pSound.m_vecOrigin ) || !self.FVisible ( pSound.m_vecOrigin )) )
						{
							// scent is behind or occluded
							return GetScheduleOfType( SCHED_SQUID_SNIFF_AND_EAT );
						}

						// food is right out in the open. Just go get it.
						return GetScheduleOfType( SCHED_SQUID_EAT );
					}
					
					if( self.HasConditions( bits_COND_CAN_RANGE_ATTACK1 ) )
					{
						return GetScheduleOfType( SCHED_RANGE_ATTACK1 );
					}

					if( self.HasConditions( bits_COND_CAN_MELEE_ATTACK1 ) )
					{
						return GetScheduleOfType( SCHED_MELEE_ATTACK1 );
					}

					if( self.HasConditions( bits_COND_CAN_MELEE_ATTACK2 ) )
					{
						return GetScheduleOfType( SCHED_MELEE_ATTACK2 );
					}
					
					return GetScheduleOfType( SCHED_CHASE_ENEMY );
				}
			}
			
			return BaseClass.GetSchedule();
		}


		//=========================================================
		// GetScheduleOfType
		//=========================================================
		Schedule@ GetScheduleOfType( int Type )
		{
			switch( Type )
			{
				case SCHED_RANGE_ATTACK1: return slSquidRangeAttack1;
				case SCHED_SQUID_HURTHOP: return slSquidHurtHop;
				case SCHED_SQUID_SEECRAB: return slSquidSeeCrab;
				case SCHED_SQUID_EAT: return slSquidEat;
				case SCHED_SQUID_SNIFF_AND_EAT: return slSquidSniffAndEat;
				case SCHED_SQUID_WALLOW: return slSquidWallow;
				case SCHED_CHASE_ENEMY: return slSquidChaseEnemy;

			}
			return BaseClass.GetScheduleOfType( Type );
		}

		//=========================================================
		// Start task - selects the correct activity and performs
		// any necessary calculations to start the next task on the
		// schedule.  OVERRIDDEN for bullsquid because it needs to
		// know explicitly when the last attempt to chase the enemy
		// failed, since that impacts its attack choices.
		//=========================================================
		void StartTask( Task@ pTask )
		{
			self.m_iTaskStatus = TASKSTATUS_RUNNING;

			switch( pTask.iTask )
			{
				case TASK_MELEE_ATTACK2:
				{
					switch( Math.RandomLong ( 0, 2 ) )
					{
						case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_attackgrowl.wav", 1, ATTN_NORM );
						break;

						case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_attackgrowl2.wav", 1, ATTN_NORM );	
						break;

						case 2: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "bullchicken/bc_attackgrowl3.wav", 1, ATTN_NORM );
						break;
					}

					BaseClass.StartTask( pTask );
					break;
				}
				case TASK_SQUID_HOPTURN:
				{
					self.SetActivity( ACT_HOP );
					self.MakeIdealYaw( self.m_vecEnemyLKP );
					break;
				}
				case TASK_GET_PATH_TO_ENEMY:
					/*if( ( self.m_hEnemy.GetEntity().pev.origin, bits_MF_TO_ENEMY, self.m_hEnemy.GetEntity() is !null ) != 0  )
					{
						self.m_iTaskStatus = TASKSTATUS_COMPLETE;
					}
					else
					{
						//g_Game.AlertMessage(at_console, "GetPathToEnemy failed!!\n" );
						self.TaskFail();
					}*/
				default:
				{
					BaseClass.StartTask( pTask );
					break;
				}
			}
		}

		//=========================================================
		// RunTask
		//=========================================================
		void RunTask( Task@ pTask )
		{
			switch( pTask.iTask )
			{
				case TASK_SQUID_HOPTURN:
				{
					self.MakeIdealYaw( self.m_vecEnemyLKP );
					self.ChangeYaw( int(self.pev.yaw_speed) );
			
					if( self.m_fSequenceFinished )
					{
						self.m_iTaskStatus = TASKSTATUS_COMPLETE;
						self.TaskComplete();
					}
					else
					{
						g_Game.AlertMessage( at_console, "No landed\n" );
					}

					break;
				}
				
				default:
				{
					BaseClass.RunTask( pTask );
					break;
				}
			}
		}

		//=========================================================
		// GetIdealState - Overridden for Bullsquid to deal with
		// the feature that makes it lose interest in headcrabs for 
		// a while ifsomething injures it. 
		//=========================================================
		MONSTERSTATE GetIdealState()
		{
			int	iConditions;

			iConditions = self.IScheduleFlags();

			// If no schedule conditions, the new ideal state is probably the reason we're in here.
			switch( self.m_MonsterState )
			{
				case MONSTERSTATE_COMBAT:
				/*
				COMBAT goes to ALERT upon death of enemy
				*/
				{
						if(self.m_hEnemy.GetEntity() is null && ( iConditions & bits_COND_LIGHT_DAMAGE != 0 || iConditions & bits_COND_HEAVY_DAMAGE != 0) && !self.m_hEnemy.GetEntity().pev.ClassNameIs( "monster_headcrab" ) ) //if(self.m_hEnemy.GetEntity() !is null && (iConditions & bits_COND_LIGHT_DAMAGE || iConditions & bits_COND_HEAVY_DAMAGE) && !self.m_hEnemy.GetEntity().pev.ClassNameIs( "monster_headcrab" ) )
						{
							// If the squid has a headcrab enemy and something hurts it, it's going to forget about the crab for a while.
							self.m_hEnemy = null;
							self.m_IdealMonsterState = MONSTERSTATE_ALERT;
						}
						break;
				}
			}
			

			self.m_IdealMonsterState = GetIdealState();

			return self.m_IdealMonsterState;
		}
	}

	array<ScriptSchedule@>@ CBullchedules;

	ScriptSchedule slSquidRangeAttack1
	(

			bits_COND_NEW_ENEMY			|
			bits_COND_ENEMY_DEAD		|
			bits_COND_HEAVY_DAMAGE		|
			bits_COND_ENEMY_OCCLUDED	|
			bits_COND_NO_AMMO_LOADED,
			0,
			"Squid Range Attack1"
	);

	ScriptSchedule slSquidChaseEnemy
	(
			bits_COND_NEW_ENEMY			|
			bits_COND_ENEMY_DEAD		|
			bits_COND_SMELL_FOOD		|
			bits_COND_CAN_RANGE_ATTACK1	|
			bits_COND_CAN_MELEE_ATTACK1	|
			bits_COND_CAN_MELEE_ATTACK2	|
			bits_COND_TASK_FAILED		|
			bits_COND_HEAR_SOUND,
				
			bits_SOUND_DANGER			|
			bits_SOUND_MEAT,
			"Squid Chase Enemy"
	);

	ScriptSchedule slSquidHurtHop
	(
			0,
			0,
			"Squid HurtHop"
	);

	ScriptSchedule slSquidSeeCrab
	(
			bits_COND_LIGHT_DAMAGE		|
			bits_COND_HEAVY_DAMAGE,
			0,
			"Squid See Crab"
	);

	ScriptSchedule slSquidEat
	(
			bits_COND_LIGHT_DAMAGE	|
			bits_COND_HEAVY_DAMAGE	|
			bits_COND_NEW_ENEMY	,
				
			// even though HEAR_SOUND/SMELL FOOD doesn't break this schedule, we need this mask
			// here or the monster won't detect these sounds at ALL while running this schedule.
			bits_SOUND_MEAT			|
			bits_SOUND_CARCASS,
			"Squid Eat"
	);

	ScriptSchedule slSquidSniffAndEat
	(
			bits_COND_LIGHT_DAMAGE	|
			bits_COND_HEAVY_DAMAGE	|
			bits_COND_NEW_ENEMY	,
				
			// even though HEAR_SOUND/SMELL FOOD doesn't break this schedule, we need this mask
			// here or the monster won't detect these sounds at ALL while running this schedule.
			bits_SOUND_MEAT			|
			bits_SOUND_CARCASS,
			"Squid Sniff And Eat"
	);

	ScriptSchedule slSquidWallow
	(
			bits_COND_LIGHT_DAMAGE	|
			bits_COND_HEAVY_DAMAGE	|
			bits_COND_NEW_ENEMY	,
				
			// even though HEAR_SOUND/SMELL FOOD doesn't break this schedule, we need this mask
			// here or the monster won't detect these sounds at ALL while running this schedule.
			bits_SOUND_GARBAGE		|
			bits_SOUND_MEAT			|
			bits_SOUND_CARCASS,

			"Squid Wallow"
	);

	void InitSchedules()
	{
		slSquidRangeAttack1.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSquidRangeAttack1.AddTask( ScriptTask(TASK_FACE_IDEAL) );
		slSquidRangeAttack1.AddTask( ScriptTask(TASK_RANGE_ATTACK1) );
		slSquidRangeAttack1.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );

		slSquidChaseEnemy.AddTask( ScriptTask(TASK_SET_FAIL_SCHEDULE, float(SCHED_RANGE_ATTACK1)) );// !!!OEM - this will stop nasty squid oscillation.
		slSquidChaseEnemy.AddTask( ScriptTask(TASK_GET_PATH_TO_ENEMY) );
		slSquidChaseEnemy.AddTask( ScriptTask(TASK_RUN_PATH) );
		slSquidChaseEnemy.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );

		slSquidHurtHop.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSquidHurtHop.AddTask( ScriptTask(TASK_SOUND_WAKE) );
		//slSquidHurtHop.AddTask( ScriptTask(TASK_SQUID_HOPTURN) );
		slSquidHurtHop.AddTask( ScriptTask(TASK_FACE_ENEMY) );// in case squid didn't turn all the way in the air.

		slSquidSeeCrab.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSquidSeeCrab.AddTask( ScriptTask(TASK_SOUND_WAKE) );
		slSquidSeeCrab.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EXCITED)) );
		slSquidSeeCrab.AddTask( ScriptTask(TASK_FACE_ENEMY) );

		slSquidEat.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSquidEat.AddTask( ScriptTask(TASK_EAT, float( 10 ) ) );// this is in case the squid can't get to the food
		slSquidEat.AddTask( ScriptTask(TASK_STORE_LASTPOSITION) );
		slSquidEat.AddTask( ScriptTask(TASK_GET_PATH_TO_BESTSCENT) );
		slSquidEat.AddTask( ScriptTask(TASK_WALK_PATH) );
		slSquidEat.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );
		slSquidEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EAT)) );
		slSquidEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EAT)) );
		slSquidEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EAT)) );
		slSquidEat.AddTask( ScriptTask(TASK_EAT, float( 50 ) ) );
		slSquidEat.AddTask( ScriptTask(TASK_GET_PATH_TO_LASTPOSITION) );
		slSquidEat.AddTask( ScriptTask(TASK_WALK_PATH) );
		slSquidEat.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );
		slSquidEat.AddTask( ScriptTask(TASK_CLEAR_LASTPOSITION) );

		slSquidSniffAndEat.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_EAT, float( 10 ) ) );// this is in case the squid can't get to the food
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_DETECT_SCENT)) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_STORE_LASTPOSITION) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_GET_PATH_TO_BESTSCENT) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_WALK_PATH) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EAT)) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EAT)) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_EAT)) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_EAT, float( 50 ) ) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_GET_PATH_TO_LASTPOSITION) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_WALK_PATH) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );
		slSquidSniffAndEat.AddTask( ScriptTask(TASK_CLEAR_LASTPOSITION) );

		slSquidWallow.AddTask( ScriptTask(TASK_STOP_MOVING) );
		slSquidWallow.AddTask( ScriptTask(TASK_EAT, float( 10 ) ) );// this is in case the squid can't get to the stinkiness
		slSquidWallow.AddTask( ScriptTask(TASK_STORE_LASTPOSITION) );
		slSquidWallow.AddTask( ScriptTask(TASK_GET_PATH_TO_BESTSCENT) );
		slSquidWallow.AddTask( ScriptTask(TASK_WALK_PATH) );
		slSquidWallow.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );
		slSquidWallow.AddTask( ScriptTask(TASK_PLAY_SEQUENCE, float(ACT_INSPECT_FLOOR)) );
		slSquidWallow.AddTask( ScriptTask(TASK_EAT, float( 50 ) ) );// keeps squid from eating or sniffing anything else for a while.
		slSquidWallow.AddTask( ScriptTask(TASK_GET_PATH_TO_LASTPOSITION) );
		slSquidWallow.AddTask( ScriptTask(TASK_WALK_PATH) );
		slSquidWallow.AddTask( ScriptTask(TASK_WAIT_FOR_MOVEMENT) );
		slSquidWallow.AddTask( ScriptTask(TASK_CLEAR_LASTPOSITION) );

		array<ScriptSchedule@> scheds =
		{
			slSquidRangeAttack1,
			slSquidChaseEnemy,
			slSquidHurtHop,
			slSquidSeeCrab,
			slSquidEat,
			slSquidSniffAndEat,
			slSquidWallow,
		};

		@CBullchedules = @scheds;
	}

	//=========================================================
	// monster-specific schedule types
	//=========================================================
	enum eBullSchedules
	{
		SCHED_SQUID_HURTHOP = LAST_COMMON_SCHEDULE + 1,
		SCHED_SQUID_SMELLFOOD,
		SCHED_SQUID_SEECRAB,
		SCHED_SQUID_EAT,
		SCHED_SQUID_SNIFF_AND_EAT,
		SCHED_SQUID_WALLOW
	};

	//=========================================================
	// monster-specific tasks
	//=========================================================
	enum eBullTasks
	{
		TASK_SQUID_HOPTURN = LAST_COMMON_TASK + 1
	};

	void Register()
	{
		InitSchedules();
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterBullCustom::CBullCustom", "monster_bullchicken_custom");
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterBullCustom::CSquidSpit", "proj_squidpit");
	}

} // end of namespace