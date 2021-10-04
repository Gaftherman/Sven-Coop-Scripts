enum glock_e 
{
	GLOCK_IDLE1 = 0,
	GLOCK_DRAW,
	GLOCK_RELOAD,
	GLOCK_SHOOT
};

const int HANDGUN_DEFAULT_GIVE = 48;
const int HANDGUN_MAX_CARRY = 200;
const int HANDGUN_WEIGHT = 10;

class weapon_hlnuked_handgun : ScriptBasePlayerWeaponEntity, weapon_base
{
	private CBasePlayer@ m_pPlayer = null;
	private int m_iShell;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/hlnuked/w_pistol.mdl" );
		
		self.m_iDefaultAmmo = HANDGUN_DEFAULT_GIVE;

		self.FallInit(); // Get ready to fall down.
	}
	
	void Precache()
	{
		KickPrecache();

		g_Game.PrecacheModel( "models/hlnuked/v_pistol.mdl" ); // View model
		g_Game.PrecacheModel( "models/hlnuked/w_pistol.mdl" ); // World model
		g_Game.PrecacheModel( "models/hlnuked/p_pistol.mdl" ); // Player model
		
		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" ); // Brass shell

		g_SoundSystem.PrecacheSound( "hlnuked/pistol_fire.wav" ); // Pistol fire sound
		g_SoundSystem.PrecacheSound( "hlnuked/pistol_deploy.wav" ); // Pistol deploy sound
		g_SoundSystem.PrecacheSound( "hlnuked/pistol_reload.wav" ); // Pistol fake reload sound
		
		g_Game.PrecacheGeneric( "sprites/hl_nuked/weapon_hlnuked_handgun.txt" );
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= HANDGUN_MAX_CARRY;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot 		= 1;
		info.iPosition 	= 4;
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY | ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= HANDGUN_WEIGHT;
		
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

		return self.DefaultDeploy( self.GetV_Model( "models/hlnuked/v_pistol.mdl" ), self.GetP_Model( "models/hlnuked/p_pistol.mdl" ), GLOCK_DRAW, "onehanded" );
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
			PlayEmptySound();
			return;
		}
			
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		
		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( GLOCK_SHOOT, 0, 0 );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );

		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "hlnuked/pistol_fire.wav", Math.RandomFloat( 0.9, 1.0 ), ATTN_NORM );

		g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

		Vector vecShellVelocity = m_pPlayer.pev.velocity + g_Engine.v_right * -60.0 + g_Engine.v_up * Math.RandomFloat( 140.0, 150.0 ) + g_Engine.v_forward * 10;
		g_EntityFuncs.EjectBrass( self.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_up * -12 + g_Engine.v_forward * 18 + g_Engine.v_right * 6, vecShellVelocity, self.pev.angles.y, m_iShell, TE_BOUNCE_SHELL );
			
		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = g_Engine.v_forward;
				
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, Vector( 0.01, 0.01, 0.01 ), 8192, BULLET_PLAYER_9MM, 0 );
		m_pPlayer.pev.punchangle.x -= 1;

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
		self.m_flNextSecondaryAttack = g_Engine.time + 0.35;

		// Decal
		TraceResult tr;
		float x, y;
			
		g_Utility.GetCircularGaussianSpread( x, y );
			
		Vector vecSpread = Vector( 0.01, 0.01, 0.01 );
		Vector vecDir = vecAiming 
						+ x * vecSpread.x * g_Engine.v_right 
						+ y * vecSpread.y * g_Engine.v_up;

		Vector vecEnd = vecSrc + vecDir * 4096;
			
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
			
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
				if( pHit is null || pHit.IsBSPModel() )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_9MM );
			}
		}

		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) != 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) % 12 == 0)
		{
			FakeReload();
			self.m_flNextPrimaryAttack = g_Engine.time + 1;
			self.m_flNextSecondaryAttack = g_Engine.time + 1.2;
			// self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		}
	}
	
	void SecondaryAttack()
	{
		Kick();
	}

	void Reload()
	{

	}

	void FakeReload()
	{
		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0)
			return;

		self.SendWeaponAnim( GLOCK_RELOAD, 0, 0  );

		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		Idle( AUTOAIM_10DEGREES );
	}

}

string GetHLNukedandgunName()
{
	return "weapon_hlnuked_handgun";
}

void RegisterHLNukedhandgun()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hlnuked_handgun", GetHLNukedandgunName() );
	g_ItemRegistry.RegisterWeapon( GetHLNukedandgunName(), "hl_nuked", "9mm" );
}
