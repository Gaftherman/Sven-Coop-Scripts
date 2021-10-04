
enum rpg_e 
{
	RPG_IDLE = 0,
	RPG_DRAW,
	RPG_FIRE
};

const int RPG_DAMAGE 		= int(g_EngineFuncs.CVarGetFloat( "sk_plr_rpg" ));
const int RPG_DEFAULT_GIVE 	= 5;
const int RPG_WEIGHT 		= 20;
const int RPG_MAX_CARRY 	= 50;

//=========================================================
// Create Rpg
//=========================================================
CRpgRocket@ CreateRpgRocket( Vector& in vecOrigin, Vector& in vecAngles, CBaseEntity@ pOwner, weapon_hlnuked_rpg@ pLauncher )
{
	CBaseEntity@ pre_pRocket = g_EntityFuncs.CreateEntity( "hlnuked_rpg_rocket", null, false );
	CRpgRocket@ pRocket = cast<CRpgRocket@>(CastToScriptClass(pre_pRocket));
	
	g_EntityFuncs.SetOrigin( pRocket.self, vecOrigin );
	pRocket.pev.angles = vecAngles;
	pRocket.Spawn();
	pRocket.cSetTouch();
	@pRocket.m_pLauncher = @pLauncher; // remember what RPG fired me. 
	// pRocket.m_pLauncher.m_cActiveRockets++; // register this missile as active for the launcher
	@pRocket.pev.owner = @pOwner.edict();

	return pRocket;
}

class CRpgRocket : ScriptBaseEntity
{
	private int m_iTrail;
	private float m_flIgniteTime;
	private int g_sModelIndexFireball;
	private int g_sModelIndexWExplosion;
	weapon_hlnuked_rpg@ m_pLauncher; // pointer back to the launcher that fired me. 

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

        self.pev.dmg = RPG_DAMAGE;
        g_EngineFuncs.VecToAngles( self.pev.velocity, self.pev.angles );
    }

    //=========================================================
    // Rocket Tocuh
    //=========================================================
	void RocketTouch( CBaseEntity@ pOther )
	{
		if ( m_pLauncher !is null )
		{
			// my launcher is still around, tell it I'm dead.
			m_pLauncher.m_cActiveRockets--;
		}
		
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

		iScale = 5;

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
		msg.WriteByte( iScale * 8 ); // scale * 10
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

		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, (self.pev.dmg * 1.97), CLASS_NONE, DMG_BLAST | DMG_ALWAYSGIB );	

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
		msg.WriteByte( 8 ); // life
		msg.WriteByte( 3 ); // width
		msg.WriteByte( 224 ); // r, g, b
		msg.WriteByte( 224 ); // r, g, b
		msg.WriteByte( 225 ); // r, g, b
		msg.WriteByte( 200 ); // brightness
		msg.End(); // move PHS/PVS data sending into here (SEND_ALL, SEND_PVS, SEND_PHS)

        m_flIgniteTime = g_Engine.time;

        // set to follow laser spot
		// SetThink( ThinkFunction( FollowThink ) );
		// self.pev.nextthink = g_Engine.time + 0.1;
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
		
		// g_EntityFuncs.CreateExplosion( tr.vecEndPos, self.pev.angles, self.pev.owner, int( self.pev.dmg ), false ); // Effect
		// g_WeaponFuncs.RadiusDamage( tr.vecEndPos, self.pev, self.pev.owner.vars, self.pev.dmg, ( self.pev.dmg / 3 ), CLASS_NONE, DMG_BLAST );
		
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
		
		// g_EntityFuncs.CreateExplosion( tr.vecEndPos, self.pev.angles, self.pev.owner, int( self.pev.dmg ), false ); // Effect
		// g_WeaponFuncs.RadiusDamage( tr.vecEndPos, self.pev, self.pev.owner.vars, self.pev.dmg, ( self.pev.dmg * 3 ), CLASS_NONE, DMG_BLAST );
		
		g_EntityFuncs.Remove( pThis );
	}

	void cSetTouch()
	{
		SetTouch( TouchFunction( RocketTouch ) );
	}
}

class weapon_hlnuked_rpg : ScriptBasePlayerWeaponEntity, weapon_base
{
	private CBasePlayer@ m_pPlayer = null;

	int m_cActiveRockets; // How many missiles in flight from this launcher right now?

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/hlnuked/w_rpg.mdl" ); // World model
		
		self.m_iDefaultAmmo = RPG_DEFAULT_GIVE;

		self.FallInit(); // Get ready to fall down.
	}

	void Precache()
	{
		KickPrecache();

        g_Game.PrecacheModel("models/hlnuked/w_rpg.mdl"); // World model
        g_Game.PrecacheModel("models/hlnuked/v_rpg.mdl"); // View model
        g_Game.PrecacheModel("models/hlnuked/p_rpg.mdl"); // Player model

		g_Game.PrecacheOther("hlnuked_rpg_rocket"); // Precache rocket entity

		g_SoundSystem.PrecacheSound("hlnuked/rpg_fire.wav"); // Rpg fire sound
		g_SoundSystem.PrecacheSound("hlnuked/rpg_deploy.wav"); // Rpg deploy sound

		g_Game.PrecacheGeneric("sprites/hl_nuked/weapon_hlnuked_rpg.txt");
    }

	bool GetItemInfo( ItemInfo& out info )
	{
        info.iMaxAmmo1  = RPG_MAX_CARRY;
        info.iMaxAmmo2  = -1;
        info.iMaxClip   = WEAPON_NOCLIP;
        info.iSlot      = 4;
        info.iPosition  = 4;
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY | ITEM_FLAG_NOAUTORELOAD;
        info.iWeight    = RPG_WEIGHT;

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
	
		return self.DefaultDeploy( self.GetV_Model( "models/hlnuked/v_rpg.mdl" ), self.GetP_Model( "models/hlnuked/p_rpg.mdl" ), RPG_DRAW, "gauss");
    }

	void PrimaryAttack()
	{
		if( self.pev.iuser1 == 1)
        {
		    Deploy();
			return;
        }

		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			self.PlayEmptySound();
			return;
		}

        m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
        m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

        // player "shoot" animation
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		self.SendWeaponAnim( RPG_FIRE );

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );

		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "hlnuked/rpg_fire.wav", 1, ATTN_NORM );

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 16 + g_Engine.v_right * 8 + g_Engine.v_up * -8;

        CRpgRocket@ pRocket = CreateRpgRocket( vecSrc, m_pPlayer.pev.v_angle, m_pPlayer, this );

		m_pPlayer.pev.punchangle.x = -3.0;

        g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );// RpgRocket::Create stomps on globals, so remake.
        //pRocket->pev->velocity = /*pRocket->pev->velocity + */gpGlobals->v_forward /* * DotProduct( m_pPlayer->pev->velocity, gpGlobals->v_forward )*/;

        // firing RPG no longer turns on the designator. ALT fire is a toggle switch for the LTD.
        // Ken signed up for this as a global change (sjb)

        self.m_flNextPrimaryAttack =  g_Engine.time + 0.66;
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

string GetHLNukedRpgName()
{
	return "weapon_hlnuked_rpg";
}

void RegisterHLNukedRpg()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "CRpgRocket", "hlnuked_rpg_rocket" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hlnuked_rpg", GetHLNukedRpgName() );
	g_ItemRegistry.RegisterWeapon( GetHLNukedRpgName(), "hl_nuked", "rockets" );
}