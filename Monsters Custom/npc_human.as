namespace MonsterHuman
{
	class CHuman : ScriptBaseMonsterEntity
	{
		//=========================================================
		// Classify - indicates this monster's place in the 
		// relationship table.
		//=========================================================
		int	Classify()
		{
			return	self.GetClassification( CLASS_PLAYER_ALLY );
		}	 

		//=========================================================
		// SetYawSpeed - allows each sequence to have a different
		// turn rate associated with it.
		//=========================================================
		void SetYawSpeed()
		{
			self.pev.yaw_speed = 240;
		}

		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
		{
			if(pevAttacker is null)
				return 0;
                
            CBaseEntity@ pAttacker = g_EntityFuncs.Instance( pevAttacker );

			if(self.CheckAttacker( pAttacker ))
				return 0;

            pAttacker.SUB_UseTargets( @pAttacker, USE_TOGGLE, 0 );
				
			return BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
		}

		void TraceAttack( entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType)
		{
			if (bitsDamageType & DMG_SHOCK != 0)
				return;

			BaseClass.TraceAttack( pevAttacker, flDamage, vecDir, ptr, bitsDamageType );
		}

		//=========================================================
		// Spawn
		//=========================================================
		void Spawn()
		{
			Precache();

			g_EntityFuncs.SetModel( self, self.pev.model );
			g_EntityFuncs.SetSize( self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX );

			pev.solid				= SOLID_SLIDEBOX;
			pev.movetype			= MOVETYPE_STEP;
			self.m_bloodColor		= BLOOD_COLOR_RED;
			pev.effects				= 0;
			pev.health				= 100;
			self.m_flFieldOfView	= 0.5;
			self.m_MonsterState		= MONSTERSTATE_NONE;
			self.m_afCapability		= bits_CAP_HEAR | bits_CAP_TURN_HEAD | bits_CAP_DOORS_GROUP | bits_CAP_USE_TANK;

			self.m_FormattedName	= "Human";

			self.MonsterInit();
		}

		void Killed( entvars_t@ pevAttacker, int iGib )
		{
			BaseClass.Killed( pevAttacker, iGib ); // 1: Gib - 0: Never gib
		}
    }	

	void Register()
	{
		g_CustomEntityFuncs.RegisterCustomEntity("MonsterHuman::CHuman", "npc_human");
	}
}