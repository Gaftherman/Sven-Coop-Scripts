enum chaingun_e
{
	CHAINGUN_IDLE = 0,
	CHAINGUN_DRAW,
	CHAINGUN_FIRE1,
	CHAINGUN_FIRE2,
	CHAINGUN_FIRE3
};

const int CHAINGUN_DEFAULT_GIVE = 50;
const int CHAINGUN_MAX_AMMO		= 200;
const int CHAINGUN_WEIGHT 		= 15;

class weapon_hlnuked_chaingun : ScriptBasePlayerWeaponEntity, weapon_base
{
	private CBasePlayer@ m_pPlayer = null;
	private int m_iShell;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/hlnuked/w_chaingun.mdl" );

		self.m_iDefaultAmmo = CHAINGUN_DEFAULT_GIVE;

		self.FallInit(); // Get ready to fall
	}

	void Precache()
	{
		KickPrecache();

		g_Game.PrecacheModel( "models/hlnuked/v_chaingun.mdl" ); // View model
		g_Game.PrecacheModel( "models/hlnuked/w_chaingun.mdl" ); // World model
		g_Game.PrecacheModel( "models/hlnuked/p_chaingun.mdl" ); // Player model

		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" ); // Chaingun shell            

		g_SoundSystem.PrecacheSound( "hlnuked/chaingun_fire.wav" ); // Chaingun fire sound 
		g_SoundSystem.PrecacheSound( "hlnuked/rpg_deploy.wav" ); // Chaingun deploy sound

		g_Game.PrecacheGeneric( "sprites/hl_nuked/weapon_hlnuked_chaingun.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= CHAINGUN_MAX_AMMO;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot 		= 3;
		info.iPosition 	= 4;
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY | ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= CHAINGUN_WEIGHT;

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

		return self.DefaultDeploy( self.GetV_Model( "models/hlnuked/v_chaingun.mdl" ), self.GetP_Model( "models/hlnuked/p_chaingun.mdl" ), CHAINGUN_DRAW, "mp5" );
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

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		switch ( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 2 ) )
		{
			case 0: self.SendWeaponAnim( CHAINGUN_FIRE1, 0, 0 ); break;
			case 1: self.SendWeaponAnim( CHAINGUN_FIRE2, 0, 0 ); break;
			case 2: self.SendWeaponAnim( CHAINGUN_FIRE3, 0, 0 ); break;
		}

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlnuked/chaingun_fire.wav", 1.0, ATTN_NORM, 0, 95 + Math.RandomLong( 0, 10 ) );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_3DEGREES, 8192, BULLET_PLAYER_MP5, 2 );
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -1, 1 );

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + 0.096;
		if( self.m_flNextPrimaryAttack < g_Engine.time )
			self.m_flNextPrimaryAttack = g_Engine.time + 0.096;

		self.m_flNextSecondaryAttack = g_Engine.time + 0.125;
		
		// Decals
		TraceResult tr;
		float x, y;
		
		g_Utility.GetCircularGaussianSpread( x, y );
		
		Vector vecDir = vecAiming 
						+ x * VECTOR_CONE_3DEGREES.x * g_Engine.v_right 
						+ y * VECTOR_CONE_3DEGREES.y * g_Engine.v_up;

		Vector vecEnd	= vecSrc + vecDir * 4096;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
		
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
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

string GetHLNukedChaingunName()
{
	return "weapon_hlnuked_chaingun";
}

void RegisterHLNukedChaingun()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hlnuked_chaingun", GetHLNukedChaingunName() );
	g_ItemRegistry.RegisterWeapon( GetHLNukedChaingunName(), "hl_nuked", "9mm" );
}
