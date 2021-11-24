

enum devastator_e 
{
	DEVASTATOR_IDLE = 0,
	DEVASTATOR_DRAW,
	DEVASTATOR_FIRELEFT,
	DEVASTATOR_FIRERIGHT
};

const int DEVASTATOR_DAMAGE 		= int(g_EngineFuncs.CVarGetFloat( "sk_plr_gauss" ));
const int DEVASTATOR_DEFAULT_GIVE 	= 15;
const int DEVASTATOR_WEIGHT 		= 20;
const int DEVASTATOR_MAX_CARRY 		= 100;

//=========================================================
// Create Rpg
//=========================================================
CDevastatorRocket@ CreateDevastatorRocket( Vector& in vecOrigin, Vector& in vecAngles, CBaseEntity@ pOwner, weapon_hlnuked_devastator@ pLauncher )
{
	CBaseEntity@ pre_pRocket = g_EntityFuncs.CreateEntity( "devastator_rocket", null, false );
	CDevastatorRocket@ pRocket = cast<CDevastatorRocket@>(CastToScriptClass(pre_pRocket));
	
	g_EntityFuncs.SetOrigin( pRocket.self, vecOrigin );
	pRocket.pev.angles = vecAngles;
	pRocket.Spawn();
	pRocket.cSetTouch();
	@pRocket.m_pLauncher = @pLauncher; // remember what RPG fired me. 
	// pRocket.m_pLauncher.m_cActiveRockets++; // register this missile as active for the launcher
	@pRocket.pev.owner = @pOwner.edict();

	return pRocket;
}

class CDevastatorRocket : ScriptBaseEntity
{
	private int m_iTrail;
	private int g_sModelIndexFireball;
	private int g_sModelIndexWExplosion;
	private float m_flIgniteTime;
	weapon_hlnuked_devastator@ m_pLauncher; // pointer back to the launcher that fired me. 

    //=========================================================
    // Spawn
    //=========================================================
	void Spawn()
	{
        Precache();
        // motor
        self.pev.movetype = MOVETYPE_BOUNCEMISSILE;
        self.pev.solid = SOLID_BBOX;

        g_EntityFuncs.SetModel( self, "models/hlclassic/rpgrocket.mdl");
        g_EntityFuncs.SetSize( self.pev, Vector(0, 0, 0), Vector(0, 0, 0));
        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        SetThink( ThinkFunction( IgniteThink ) );
        SetTouch( TouchFunction( ExplodeTouch ) );

        // self.pev.angles.x -= 30;
        // self.pev.angles.x = -(self.pev.angles.x + 30);

        // g_EngineFuncs.MakeVectors( self.pev.angles );

        self.pev.velocity = g_Engine.v_forward * 1000;
        // self.pev.gravity = 0.0;

        self.pev.nextthink = g_Engine.time;

        self.pev.dmg = DEVASTATOR_DAMAGE;
        g_EngineFuncs.VecToAngles( self.pev.velocity, self.pev.angles );
    }

    //=========================================================
    // Rocket Tocuh
    //=========================================================
	void RocketTouch( CBaseEntity@ pOther )
	{	
		g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, "weapons/rocket1.wav" );
		SetThink( ThinkFunction( ExplodeThink ) );
		self.pev.nextthink = g_Engine.time;
	}

	void RocketThink()
	{
		self.pev.nextthink = g_Engine.time + 0.1;

		if ( self.pev.waterlevel == 0)
			return;

 		g_Utility.BubbleTrail( self.pev.origin - self.pev.velocity * 0.1, self.pev.origin, 1 );
	}

	void ExplodeThink()
	{
		int iContents = g_EngineFuncs.PointContents(self.pev.origin);
		CBaseEntity@ pThis = g_EntityFuncs.Instance( self.edict() );
		int iScale;

		iScale = 10;

		NetworkMessage msg( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
		msg.WriteByte(TE_EXPLOSION);
		msg.WriteCoord(self.pev.origin.x);
		msg.WriteCoord(self.pev.origin.y);
		msg.WriteCoord(self.pev.origin.z);
		if (iContents != CONTENTS_WATER)
		{
			msg.WriteShort(g_sModelIndexFireball);
		}
		else
		{
			msg.WriteShort(g_sModelIndexWExplosion);
		}
		msg.WriteByte(iScale); // scale * 10
		msg.WriteByte(15); // framerate
		msg.WriteByte(TE_EXPLFLAG_NOSOUND);
		msg.End();

		entvars_t@ pevOwner;

		if ( self.pev.owner !is null)
			@pevOwner = self.pev.owner.vars;
		else
			@pevOwner = null;

		switch( Math.RandomLong( 0, 2 ) )
		{
			case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_WEAPON, "hlnuked/explode3.wav", 0.75, 1.05 ); 
			break;
				
			case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_WEAPON, "hlnuked/explode4.wav", 0.75, 1.05 );
			break;	
		
			case 2: g_SoundSystem.EmitSound( self.edict(), CHAN_WEAPON, "hlnuked/explode5.wav", 0.75, 1.05 );
			break;	
		}

		@self.pev.owner = null; // can't traceline attack owner if this is set

		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, 128, CLASS_NONE, DMG_BLAST | DMG_ALWAYSGIB );

		g_EntityFuncs.Remove( pThis );
	}

    //=========================================================
    // Precache
    //=========================================================
    void Precache()
    {
		m_iTrail = g_Game.PrecacheModel( "sprites/smoke.spr" );
		g_sModelIndexFireball = g_Game.PrecacheModel( "sprites/zerogxplode.spr" );// fireball
		g_sModelIndexWExplosion = g_Game.PrecacheModel( "sprites/WXplo1.spr" );// underwater fireball

		g_Game.PrecacheModel( "models/hlclassic/rpgrocket.mdl" );
		g_SoundSystem.PrecacheSound( "weapons/rocket1.wav" );
		g_SoundSystem.PrecacheSound( "hlnuked/explode3.wav" );
		g_SoundSystem.PrecacheSound( "hlnuked/explode4.wav" );
		g_SoundSystem.PrecacheSound( "hlnuked/explode5.wav" );
    }

	void IgniteThink()
	{
        // self.pev.movetype = MOVETYPE_TOSS;

        self.pev.movetype = MOVETYPE_FLY;
        // self.pev.effects |= EF_LIGHT;

        // make rocket sound
        // g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "weapons/rocket1.wav", 1, 0.5 );

        // rocket trail
		NetworkMessage msg( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
		msg.WriteByte( TE_BEAMFOLLOW );
		msg.WriteShort( self.entindex() ); // entity
		msg.WriteShort( m_iTrail ); // model
		msg.WriteByte( 2 ); // life
		msg.WriteByte( 2 ); // width
		msg.WriteByte( 100 ); // r
		msg.WriteByte( 100 ); // g
		msg.WriteByte( 100 ); // b
		msg.WriteByte( 255 ); // brightness
		msg.End(); // move PHS/PVS data sending into here (SEND_ALL, SEND_PVS, SEND_PHS)

        m_flIgniteTime = g_Engine.time;

		if ( self.pev.waterlevel == 0 )
			return;

		g_Utility.BubbleTrail( self.pev.origin - self.pev.velocity * 0.1, self.pev.origin, 1 );
    }

	void FollowThink()
	{
		CBaseEntity@ pOther = null;
		Vector vecTarget;
		Vector vecDir;
		float flDist, flMax, flDot;
		TraceResult tr;

        Math.MakeAimVectors( self.pev.angles );

        vecTarget = g_Engine.v_forward;
        flMax = 4096;

        // Examine all entities within a reasonable radius
		while ( ( @pOther = g_EntityFuncs.FindEntityByClassname( pOther, "hllaser_spot" ) ) !is null )
		{
            g_Utility.TraceLine( self.pev.origin, pOther.pev.origin, dont_ignore_monsters, self.edict(), tr );

            // g_Game.AlertMessage( at_console, "%1" + "\n", tr.flFraction );

            if (tr.flFraction >= 0.90)
            {
				vecDir = pOther.pev.origin - self.pev.origin;
				flDist = vecDir.Length();
				vecDir = vecDir.Normalize();
				flDot = DotProduct( g_Engine.v_forward, vecDir );
                if ((flDot > 0) && (flDist * (1 - flDot) < flMax))
                {
                    flMax = flDist * (1 - flDot);
                    vecTarget = vecDir;
                }
            }
        }

        g_EngineFuncs.VecToAngles( vecTarget, self.pev.angles );

        // this acceleration and turning math is totally wrong, but it seems to respond well so don't change it.
        float flSpeed = self.pev.velocity.Length();
		if(g_Engine.time - m_flIgniteTime < 1.0)
		{
			self.pev.velocity = self.pev.velocity * 0.2 + vecTarget * ( flSpeed * 0.8 + 400 );
			if ( self.pev.waterlevel == 3 )
			{
                // go slow underwater
				if ( self.pev.velocity.Length() > 300)
				{
					self.pev.velocity = pev.velocity.Normalize() * 300;
				}
                g_Utility.BubbleTrail( self.pev.origin - self.pev.velocity * 0.1, self.pev.origin, 4 );
            }
            else
            {
				if ( self.pev.velocity.Length() > 2000 )
				{
					self.pev.velocity = self.pev.velocity.Normalize() * 2000;
				}
            }
        }
        else
        {
			if ( ( self.pev.effects &= EF_LIGHT ) == EF_LIGHT )
            {
                self.pev.effects = 0;
                g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, "weapons/rocket1.wav" );
            }
			self.pev.velocity = self.pev.velocity * 0.2 + vecTarget * flSpeed * 0.798;
			if ( self.pev.waterlevel == 0 && self.pev.velocity.Length() < 1500 )
			{
				Detonate();
			}
        }
        // g_Game.AlertMessage( at_console, "%.0f\n", flSpeed );

        self.pev.nextthink = g_Engine.time + 0.1;
    }
    
	void Detonate()
	{
		CBaseEntity@ pThis = g_EntityFuncs.Instance( self.edict() );
		
		TraceResult tr;
		Vector vecSpot; // trace starts here!

		vecSpot = self.pev.origin + Vector( 0, 0, 8 );
		g_Utility.TraceLine( vecSpot, vecSpot + Vector( 0, 0, -40 ), ignore_monsters, self.edict(), tr);
		
		g_EntityFuncs.Remove( pThis );
	}

	void ExplodeTouch( CBaseEntity@ pOther )
	{
		CBaseEntity@ pThis = g_EntityFuncs.Instance( self.edict() );
		
		TraceResult tr;
		Vector vecSpot; // trace starts here!
		
		@self.pev.enemy = @pOther.edict();
		
		vecSpot = self.pev.origin - self.pev.velocity.Normalize() * 32;
		g_Utility.TraceLine( vecSpot, vecSpot + self.pev.velocity.Normalize() * 64, ignore_monsters, self.edict(), tr );
		
		g_EntityFuncs.Remove( pThis );
	}

	void cSetTouch()
	{
		SetTouch( TouchFunction( RocketTouch ) );
	}
}

class weapon_hlnuked_devastator : ScriptBasePlayerWeaponEntity, weapon_base
{
	private CBasePlayer@ m_pPlayer = null;

	private int m_fSpotActive;
	private int iCurrentRocket;
	// int m_cActiveRockets; // how many missiles in flight from this launcher right now?

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/hlnuked/w_devastator.mdl" ); // World model
		
		self.m_iDefaultAmmo = DEVASTATOR_DEFAULT_GIVE; 
		iCurrentRocket = 0;

		self.FallInit(); // Get ready to fall down.
	}

	void Precache()
	{
		KickPrecache();
		
        g_Game.PrecacheModel("models/hlnuked/w_devastator.mdl"); // World model 
        g_Game.PrecacheModel("models/hlnuked/v_devastator.mdl"); // View model
        g_Game.PrecacheModel("models/hlnuked/p_devastator.mdl"); // Player model

		g_Game.PrecacheOther( "devastator_rocket" ); // Precache rocket entity

		g_SoundSystem.PrecacheSound("hlnuked/rpg_fire.wav"); // Rpg fire sound
		g_SoundSystem.PrecacheSound("hlnuked/rpg_deploy.wav"); // Rpg deploy sound

		g_Game.PrecacheGeneric("sprites/hl_nuked/weapon_hlnuked_devastator.txt");

    }

	bool GetItemInfo( ItemInfo& out info )
	{
        info.iMaxAmmo1  = DEVASTATOR_MAX_CARRY;
        info.iMaxAmmo2  = -1;
        info.iMaxClip   = WEAPON_NOCLIP;
        info.iSlot      = 5;
        info.iPosition  = 4;
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY | ITEM_FLAG_NOAUTORELOAD;
        info.iWeight    = DEVASTATOR_WEIGHT;

		return true;
    }

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;
			
		self.pev.iuser1 = 0;

		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( self.m_iId );
		message.End();

		return true;
	}
	
	bool Deploy()
	{	
		self.pev.iuser1 = 0;

		return self.DefaultDeploy( self.GetV_Model( "models/hlnuked/v_devastator.mdl" ), self.GetP_Model( "models/hlnuked/p_devastator.mdl" ), DEVASTATOR_DRAW, "uzis");
    }
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.SendWeaponAnim(DEVASTATOR_IDLE);
			self.pev.body = 0;			
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hl/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
			self.m_bPlayEmptySound = false;
			return false;
		}
		
		return false;
	}

	void PrimaryAttack()
	{
		if( self.pev.iuser1 == 1)
        {
		    Deploy();
			return;
        }
		
		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) != 0 )
		{
            m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
            m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

            // player "shoot" animation
            //m_pPlayer.SetAnimation(PLAYER_ATTACK1);

            g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + Vector( Math.RandomFloat(-0.7, 0.7), Math.RandomFloat(-0.7, 0.7), Math.RandomFloat(-0.7, 0.7) ) );

			Vector vecSrc; 
			if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) % 4 == 0 || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) % 4 == 3)
			{
				vecSrc = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 16 + g_Engine.v_right * 8 + g_Engine.v_up * -8;
				self.SendWeaponAnim( DEVASTATOR_FIRERIGHT, 0, 3 );
				m_pPlayer.pev.punchangle.z = -1.0;
			}
			else
			{
				vecSrc = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 16 + g_Engine.v_right * -8 + g_Engine.v_up * -8;
				self.SendWeaponAnim( DEVASTATOR_FIRELEFT, 0 , 1 );
				m_pPlayer.pev.punchangle.z = 1.0;
			}

			m_pPlayer.pev.punchangle.x = -1.0;
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "hlnuked/rpg_fire.wav", 1, ATTN_NORM );
			//g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_BODY, "weapons/glauncher.wav", 1, ATTN_NORM );

            CDevastatorRocket@ pRocket = CreateDevastatorRocket( vecSrc, m_pPlayer.pev.v_angle, m_pPlayer, this );

            //g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );// RpgRocket::Create stomps on globals, so remake.
            //pRocket->pev->velocity = /*pRocket->pev->velocity + */g_Engine.v_forward /* * DotProduct( m_pPlayer->pev->velocity, g_Engine.v_forward )*/;

            // firing RPG no longer turns on the designator. ALT fire is a toggle switch for the LTD.
            // Ken signed up for this as a global change (sjb)

			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );

			if (iCurrentRocket >= 2)
				iCurrentRocket = 0;
			else
				iCurrentRocket += 1;

        }
        else
        {
            PlayEmptySound();
        }

		float rof;

		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) % 4 == 2 || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) % 4 == 0)
			rof = 0.15;
		else
			rof = 0.066;

		self.m_flNextPrimaryAttack = g_Engine.time + rof;

		SetThink( ThinkFunction( this.Fix ) );
		self.pev.nextthink = g_Engine.time + 0.35;
    }

	void Fix()
	{
		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
		{
			self.SendWeaponAnim(DEVASTATOR_IDLE);
		}
		else
		{
			self.m_flTimeWeaponIdle = g_Engine.time + 1.0;
		}
	}

    void SecondaryAttack()
    {
        Kick();
    }

	void WeaponIdle()
	{
		Idle( AUTOAIM_5DEGREES );
    }

    void Reload(void)
    {

    }
}

string GetHLNukedDevastatorName()
{
	return "weapon_hlnuked_devastator";
}

void RegisterHLNukedDevastator()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "CDevastatorRocket", "devastator_rocket" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hlnuked_devastator", GetHLNukedDevastatorName() );
	g_ItemRegistry.RegisterWeapon( GetHLNukedDevastatorName(), "hl_nuked", "ARgrenades" );
}