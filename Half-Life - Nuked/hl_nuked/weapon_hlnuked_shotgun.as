enum shotgun_e 
{
	SHOTGUN_IDLE = 0,
	SHOTGUN_DRAW,
	SHOTGUN_FIRE
};

const int SHOTGUN_DEFAULT_AMMO 	= 10;
const int SHOTGUN_MAX_CARRY 	= 50;
const int SHOTGUN_WEIGHT 		= 15;

class weapon_hlnuked_shotgun : ScriptBasePlayerWeaponEntity, weapon_base
{
	private CBasePlayer@ m_pPlayer = null;	
	private int m_iShell;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/hlnuked/w_shotgun.mdl" );
		
		self.m_iDefaultAmmo = SHOTGUN_DEFAULT_AMMO;

		self.FallInit(); // Get ready to fall
	}

	void Precache()
	{
		KickPrecache();

		g_Game.PrecacheModel( "models/hlnuked/v_shotgun.mdl" ); // View model
		g_Game.PrecacheModel( "models/hlnuked/w_shotgun.mdl" ); // World model
		g_Game.PrecacheModel( "models/hlnuked/p_shotgun.mdl" ); // Player model

		m_iShell = g_Game.PrecacheModel( "models/shotgunshell.mdl" ); // Shotgun shell

		g_SoundSystem.PrecacheSound( "hlnuked/shotgun_fire.wav" ); // Shotgun fire sound
		g_SoundSystem.PrecacheSound( "hlnuked/shotgun_deploy.wav" ); // Shotgun deploy sound

		g_Game.PrecacheGeneric( "sprites/hl_nuked/weapon_hlnuked_shotgun.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= SHOTGUN_MAX_CARRY;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot 		= 2;
		info.iPosition 	= 4;
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY | ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= SHOTGUN_WEIGHT;

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

		return self.DefaultDeploy( self.GetV_Model( "models/hlnuked/v_shotgun.mdl" ), self.GetP_Model( "models/hlnuked/p_shotgun.mdl" ), SHOTGUN_DRAW, "shotgun" );
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
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( SHOTGUN_FIRE, 0, 0 );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlnuked/shotgun_fire.wav", Math.RandomFloat( 0.95, 1.0 ), ATTN_NORM, 0, 93 + Math.RandomLong( 0, 0x1f ) );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		m_pPlayer.FireBullets( 8, vecSrc, vecAiming, VECTOR_CONE_10DEGREES, 2048, BULLET_PLAYER_BUCKSHOT, 0 );
		m_pPlayer.pev.punchangle.x = -3.0;

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + 1.0;
		self.m_flNextSecondaryAttack = g_Engine.time + 1.2;

		// Decals
		TraceResult tr;
		float x, y;
		
		for( uint uiPellet = 0; uiPellet < 8; ++uiPellet )
		{
			g_Utility.GetCircularGaussianSpread( x, y );
			
			Vector vecDir = vecAiming 
							+ x * VECTOR_CONE_10DEGREES.x * g_Engine.v_right 
							+ y * VECTOR_CONE_10DEGREES.y * g_Engine.v_up;

			Vector vecEnd	= vecSrc + vecDir * 2048;
			
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
			
			if( tr.flFraction < 1.0 )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
					if( pHit is null || pHit.IsBSPModel() )
						g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_BUCKSHOT );
				}
			}
		}
	}

	void SecondaryAttack()
	{
		Kick();
	}

	void Reload()
	{

	}

	void WeaponIdle()
	{
		Idle( AUTOAIM_5DEGREES );
	}
}

string GetHLNukedShotgunName()
{
	return "weapon_hlnuked_shotgun";
}

void RegisterHLNukedShotgun()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hlnuked_shotgun", GetHLNukedShotgunName() );
	g_ItemRegistry.RegisterWeapon( GetHLNukedShotgunName(), "hl_nuked", "buckshot" );
}
