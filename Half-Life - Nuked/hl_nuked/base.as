	
enum crowbar_e
{
	KICK_IDLE = 0,
	KICK_ATTACK
};

mixin class weapon_base
{
    private int m_iSwing;
    private TraceResult m_trHit;

	void KickPrecache()
	{
	    g_Game.PrecacheModel( "models/hlnuked/v_kick.mdl" ); // View model

        g_Game.PrecacheModel("sprites/hl_nuked/640hud2.spr");
        g_Game.PrecacheModel("sprites/hl_nuked/640hud5.spr");
        g_Game.PrecacheModel("sprites/hl_nuked/640hud7.spr");

		g_SoundSystem.PrecacheSound( "hlnuked/kick_hitwall.wav" );

		g_SoundSystem.PrecacheSound( "weapons/cbar_hitbod1.wav" );
		g_SoundSystem.PrecacheSound( "weapons/cbar_hitbod2.wav" );
		g_SoundSystem.PrecacheSound( "weapons/cbar_hitbod3.wav" );
		g_SoundSystem.PrecacheSound( "hl/weapons/357_cock1.wav" );

		g_Game.PrecacheGeneric( "sound/hlnuked/kick_hitwall.wav" );

        g_Game.PrecacheGeneric( "sound/weapons/cbar_hitbod1.wav" );
        g_Game.PrecacheGeneric( "sound/weapons/cbar_hitbod2.wav" );
        g_Game.PrecacheGeneric( "sound/weapons/cbar_hitbod3.wav" );
        g_Game.PrecacheGeneric( "sound/hl/weapons/357_cock1.wav" );
	}

	void Kick()
	{
		m_pPlayer.pev.viewmodel = string( "models/hlnuked/v_kick.mdl" );
		m_pPlayer.pev.weaponmodel = string( );

        self.pev.iuser1 = 1;

		if( !Swing( 1 ) )
		{			
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.1;
		}
	}

	void Idle( float Autoaim )
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( Autoaim );

		if ( self.m_flTimeWeaponIdle > g_Engine.time )
		{
			self.pev.iuser1 = 1;
			return;
		}

		if( self.pev.iuser1 == 1)
        {
		    Deploy();
            return;
        }
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hl/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool Swing( int fFirst )
	{
		bool fDidHit = false;

		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * 64;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if ( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}

		if ( tr.flFraction >= 1.0 )
		{
			if( fFirst != 0 )
			{
                self.SendWeaponAnim( KICK_ATTACK );

                self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.85;

                m_pPlayer.m_szAnimExtension = "crowbar";
                
				// Player "shoot" animation
				m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
			}
		}
		else
		{
			// Hit
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

            self.SendWeaponAnim( KICK_ATTACK );

            m_pPlayer.m_szAnimExtension = "crowbar";

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// AdamR: Custom damage option
			float flDamage = 5;
			if ( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;
			// AdamR: End

			g_WeaponFuncs.ClearMultiDamage();
			
			// UNDONE - Allow crowbar to deal full damage at all times. -Giegue
			pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB );

            pEntity.pev.velocity = pEntity.pev.velocity + ( Vector(g_Engine.v_forward.x, g_Engine.v_forward.y, g_Engine.v_forward.z * 0.33) ) * 420 + g_Engine.v_up * 50;
			
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			// Play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
                self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.85;

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
	                // Gone
					if( pEntity.IsPlayer() ) // Lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
	                // End aone
					// Play thwack or smack sound
					switch( Math.RandomLong( 0, 2 ) )
					{
						case 0: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/cbar_hitbod1.wav", 1, ATTN_NORM ); 
						break;

						case 1: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/cbar_hitbod2.wav", 1, ATTN_NORM ); 
						break;

						case 2: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/cbar_hitbod3.wav", 1, ATTN_NORM ); 
						break;
					}

					m_pPlayer.m_iWeaponVolume = 128; 
                    
					if( !pEntity.IsAlive() )
						return true;
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			// Play texture hit sound
			// UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

			if( fHitWorld == true )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				
				// Override the volume here, cause we don't play texture sounds in multiplayer, 
				// and fvolbar is going to be 0 from the above call.
				fvolbar = 1;

			    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "hlnuked/kick_hitwall.wav", fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) ); 

                m_trHit = tr;
			}

		    m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 

            self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.85;

			// Delay the decal a bit
			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time + 0.2;
		}
		return fDidHit;
	}

	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}

	void SwingAgain()
	{
		Swing( 0 );
	}
}