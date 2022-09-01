//To permanently block the use of vote of a specific player, put their SteamID here.
array<string> SteamIDArray = 
{
    "STEAM_0:0:000000000",
    "STEAM_0:0:000000000",
    "STEAM_0:0:000000000",
};

funcdef void FuncVoteEnd( Vote@, bool, int );
funcdef void FuncVoteBlocked( Vote@, float );

Diffy@ g_diffy;
Timer@ g_timer;
VoteAlt@ g_vote;
BarnacleEatSpeed@ g_barnacle;

dictionary g_Player_Spamming;

CClientCommand g_DiffCommandAdmin("admin_diff", "Sets the Difficulty by a admin (0.0 - 100.0)", @DiffAdmin, ConCommandFlag::AdminOnly);
CClientCommand g_DiffCommand("diff", "Vote to change the Difficulty (0.0 - 100.0)", @Diff );

void DiffAdmin(const CCommand@ pArguments)
{
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
    string aStr = pArguments.Arg(1);

    if( pArguments.ArgC() < 1 && aStr == "" && !g_diffy.VoidDisableDiff() ) 
        return;
    
    g_diffy.SetNewDifficult(atod(aStr)/100.0);

    g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, "[SERVER] Difficulty changed by an admin\n" );
    g_Game.AlertMessage( at_logged, "[SERVER] Difficulty changed by an admin: "+pPlayer.pev.netname+"\n" );
}

void Diff(const CCommand@ pArguments)
{
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
    string Message = pArguments.Arg(1);

    if( pArguments.ArgC() < 1 && Message == "" && !g_diffy.VoidDisableDiff() ) 
        return;

    g_vote.Vote( pPlayer, Message );
}

void PluginInit()
{
    g_Module.ScriptInfo.SetAuthor( "Cubemath | Gaftherman" );
    g_Module.ScriptInfo.SetContactInfo( "Idk" );

    g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @ClientPutInServer );
    g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect );
    g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, @PlayerKilled );
    g_Hooks.RegisterHook( Hooks::Game::EntityCreated, @EntityCreated );
    g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );

    g_Player_Spamming.deleteAll();

    Diffy dif();
    Timer time();
    VoteAlt vote();
    BarnacleEatSpeed barnacle();

    @g_timer = @time;
    @g_diffy = @dif;
    @g_vote = @vote;
    @g_barnacle = @barnacle;

    g_diffy.PluginInit(); 
    g_timer.PluginInit();
}

void MapActivate()
{ 
    g_Player_Spamming.deleteAll();

    g_diffy.MapActivate(); 
    g_timer.MapActivate();

    g_vote.DelayTimer = 30;
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
    if( !g_diffy.VoidDisableDiff() ) 
    {
        pPlayer.pev.max_health = g_diffy.VoidInitialMaxHealth();
        pPlayer.pev.armortype = g_diffy.VoidInitialMaxArmor();
    }

    g_diffy.CountPeople();

    return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
    g_diffy.CountPeople();

    return HOOK_CONTINUE;
}

HookReturnCode PlayerKilled(CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib)
{
    if( g_diffy.VoidNewDifficult() == 1.0 && !((pPlayer.pev.health < -40 && iGib != GIB_NEVER) || iGib == GIB_ALWAYS) && !g_diffy.VoidDisableDiff() ) 
    {
        pPlayer.GibMonster();
        pPlayer.pev.deadflag = DEAD_DEAD;
        pPlayer.pev.effects |= EF_NODRAW;
    }

    return HOOK_CONTINUE;
}

HookReturnCode EntityCreated(CBaseEntity@ pEntity)
{
    if( pEntity.IsMonster() && !pEntity.IsNetClient() )
        g_diffy.EntitiesInThisMap.insertLast( pEntity );

    return HOOK_CONTINUE;
}

HookReturnCode ClientSay( SayParameters@ pParams ) 
{
    CBasePlayer@ pPlayer = pParams.GetPlayer();
    const CCommand@ args = pParams.GetArguments();
    string cmd = pParams.GetCommand();

    if( !g_diffy.VoidDisableDiff() && (args[0] == "/vote" && args[1] == "diff" && args.ArgC() >= 3 || args[0] == "/votediff" && args.ArgC() >= 2) )
    {	
        if( args[0] == "/vote" && args[1] == "diff" )
            g_vote.Vote( pPlayer, args[2] );
        else if( args[0] == "/votediff" )
            g_vote.Vote( pPlayer, args[1] );

        return HOOK_HANDLED;
    }

    cmd.ToUppercase();

    bool strTest = (cmd.Find("DIFF") != String::INVALID_INDEX);
    strTest = strTest || (cmd.Find("STATUS") != String::INVALID_INDEX);
    strTest = strTest || (cmd.Find("DIFFSTATUS") != String::INVALID_INDEX);
    strTest = strTest || (cmd.Find("DIFSTATUS") != String::INVALID_INDEX);
    strTest = strTest && (g_diffy.MessageTime < g_Engine.time);

    if( strTest ) 
    {
        g_diffy.Message();
    }
    
    return HOOK_CONTINUE;
}

final class Diffy
{
    /************************************/
    /*            Scheduler             */
    /************************************/
    CScheduledFunction@ CountPeopleScheduler;
    CScheduledFunction@ Enable30SecScheduler;

    /*******************************/
    /* Current Entities of the map */
    /*******************************/
    array<EHandle> EntitiesInThisMap;

    /***************/
    /* Skill names */
    /***************/
    private array<string> Skills;

    /**************/
    /* Skill data */
    /**************/
    private array<array<double>> SkillsMatrix;

    /*********************************/
    /* Current Difficulty of the map */
    /*********************************/
    private double NewDifficult = 0.5;
    double VoidNewDifficult() { return NewDifficult; }

    /******************************/
    /* last Difficulty of the map */
    /******************************/
    private double LastDifficult = 0.0;
    double VoidLastDifficult() { return LastDifficult; }

    /********************************/
    /* Current MaxHealth of the map */
    /********************************/
    private double InitialMaxHealth = 100.0f;
    double VoidInitialMaxHealth() { return InitialMaxHealth; }

    /***************************************/
    /* Current MaxHealth Charge of the map */
    /***************************************/
    private double InitialMaxHealthCharge = 0.0;
    double VoidInitialMaxHealthCharge() { return InitialMaxHealthCharge; }

    /*******************************/
    /* Current MaxArmor of the map */
    /*******************************/
    private double InitialMaxArmor = 100.0f;
    double VoidInitialMaxArmor() { return InitialMaxArmor; }

    /**************************************/
    /* Current MaxArmor Charge of the map */
    /**************************************/
    private double InitialMaxArmorCharge = 0.0;
    double VoidInitialMaxArmorCharge() { return InitialMaxArmorCharge; }

    /*************************/
    /* Last MaxArmor changed */
    /*************************/
    private double LastInitialMaxArmor = 0.0;
    double VoidLastInitialMaxArmor() { return LastInitialMaxArmor; }

    /*********************************/
    /* Current Speed of the monsters */
    /*********************************/
    private double InitialMonsterSpeed = 1.0f;
    double VoidInitialMonsterSpeed() { return InitialMonsterSpeed; }

    /*****************/
    /* Enable Diffy? */
    /*****************/
    private bool DisableDiff = false;
    bool VoidDisableDiff() { return DisableDiff; }

    /******************************************************/
    /* Number of Players that are connected to the Server */
    /******************************************************/
    private int PlayerNumNow = 0;
    
    /*******************************************************************/
    /* Number of Players that are connected at the end of the last map */
    /*******************************************************************/
    private int LastPlayerNum = 0;

    /**************************/
    /* Used to internal calcs */
    /**************************/
    private double OldEngineTime = 0.0;

    /****************/
    /* Message Time	*/
    /****************/
    double MessageTime = 0.0;

    /*******************************/
    /* Difficulty per people array */
    /*******************************/
    private array<double> DiffPerPeople = 
    {
        0.500, //0
        0.500, //1
        0.550, //2
        0.600, //3
        0.650, //4
        0.700, //5
        0.710, //6
        0.720, //7
        0.730, //8
        0.740, //9
        0.750, //10
        0.760, //11
        0.770, //12
        0.780, //13
        0.790, //14
        0.800, //15
        0.805, //16
        0.810, //17
        0.815, //18
        0.820, //19
        0.825, //20
        0.830, //21
        0.835, //22
        0.840, //23
        0.845, //24
        0.850, //25
        0.850, //26
        0.850, //27
        0.850, //28
        0.850, //29
        0.850, //30
        0.850, //31
        0.850  //32
    };
    
    /****************************/
    /* Difficulty borders array */
    /****************************/
    array<double> DiffBorders = 
    {
        0.00, 0.10, 0.30, 0.50, 0.70, 0.90, 1.00
    };

    /***************************/
    /* Player max health array */
    /***************************/
    private array<double> PlayerMaxHealth = 
    {
        10000.0, 200.0, 100.0, 100.0, 100.0, 100.0, 1.0, 1.0
    };
    double VoidPlayerMaxHealth() { return MaxArray( PlayerMaxHealth ); }

    /**********************************/
    /* Player max health charge array */
    /**********************************/
    private array<double> PlayerMaxHealthCharge = 
    {
        1000.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    };
    double VoidPlayerMaxHealthCharge() { return MaxArray( PlayerMaxHealthCharge ); }

    /**************************/
    /* Player max armor array */
    /**************************/
    private array<double> PlayerMaxArmor = 
    {
        10000.0, 200.0, 100.0, 100.0, 100.0, 100.0, 1.0, 0.0
    };
    double VoidPlayerMaxArmor() { return MaxArray( PlayerMaxArmor ); }

    /*********************************/
    /* Player max armor charge array */
    /*********************************/
    private array<double> PlayerMaxArmorCharge = 
    {
        1000.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    };
    double VoidPlayerMaxArmorCharge() { return MaxArray( PlayerMaxArmorCharge ); }

    /***********************/
    /* Monster speed array */
    /***********************/
    private array<double> MonsterSpeedMultiplier =
    {
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 1.8
    };
    double VoidMonsterSpeedMultiplier() { return MaxArray( MonsterSpeedMultiplier ); }

    Diffy()
    {	
        NewDifficult = 0.5;
        PlayerNumNow = 0;
        LastPlayerNum = 0;
        OldEngineTime = g_Engine.time;
        MessageTime = 0.0;
        LastDifficult = 0.0;
        DisableDiff = false;

        ReadSkill();
        ChangeMaxHealth();
        Think();
    }

    void PluginInit()
    {
        IgnoreDyff(); 
        CheckEntitiesInThisMap();

        MessageTime = 0.0;
        LastPlayerNum = Math.clamp( 0, 32, PlayerNumNow );

        SetNewDifficult(DiffPerPeople[LastPlayerNum]);
        
        CountPeople();
    }

    void MapActivate()
    {
        IgnoreDyff(); 
        CheckEntitiesInThisMap();

        MessageTime = 0.0;
        LastPlayerNum = Math.clamp( 0, 32, PlayerNumNow );

        double DifficulSelected = (DiffPerPeople[LastPlayerNum]);;

        // After changing the difficulty, it will remain until after you reset the map twice.(WIP)
        /*if( g_timer.Fails % 2 == 1 )
        {
            DifficulSelected = (DiffPerPeople[LastPlayerNum]);
        }
        else
        {
            DifficulSelected = LastDifficult;
        }*/

        SetNewDifficult(DifficulSelected);
        
        CountPeople();

        if( Enable30SecScheduler !is null )
            g_Scheduler.RemoveTimer(Enable30SecScheduler);

        @Enable30SecScheduler = g_Scheduler.SetTimeout( @this, "Message", 33.0f );
    }

    void Message()
    {
        MessageTime = g_Engine.time + 15.0f;
        g_Game.AlertMessage( at_logged, GetMessage() + g_timer.GetMessage(0) +"\n"  );
        g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, GetMessage() + g_timer.GetMessage(0) + "\n"  );
    }

    void SetNewDifficult(double NewDiff)
    {
        if( DisableDiff ) 
            return;

        if( NewDiff < DiffBorders[0] ) NewDiff = DiffBorders[0];
        if( NewDiff > DiffBorders[DiffBorders.length()-1] ) NewDiff = DiffBorders[DiffBorders.length()-1];
        if( NewDiff < (DiffBorders[0]+0.001) && NewDiff > DiffBorders[0] ) NewDiff = (DiffBorders[0]+0.001);
        if( NewDiff > (DiffBorders[DiffBorders.length()-1]-0.001) && NewDiff < DiffBorders[DiffBorders.length()-1] ) NewDiff = (DiffBorders[DiffBorders.length()-1]-0.001);

        NewDifficult = NewDiff;
        LastDifficult = NewDifficult;

        ChangeSkill();
        ChangeMaxHealth();
        ChangeVelocity();
        CheckPointDisabled();
    }

    void CountPeople()
    {
        if( g_Engine.time < 30.0f )
        {
            if( CountPeopleScheduler is null )
            {
                @CountPeopleScheduler = g_Scheduler.SetTimeout( @this, "CountPeople", 30.0f-g_Engine.time);
            }
            return;
        }

        PlayerNumNow = g_PlayerFuncs.GetNumPlayers();

        if( PlayerNumNow == 0 )
        {
            g_timer.Fails = 0;
            g_timer.OldMap = "";
        }

    }

    void ReadSkill()
    {
        File@ pFile = g_FileSystem.OpenFile( "scripts/plugins/store/Matrix.txt", OpenFile::READ );

        if( pFile is null || !pFile.IsOpen() ) 
            return;

        string line;

        while( !pFile.EOFReached() )
        {
            pFile.ReadLine( line );
                
            if( line.Find("//") != String::INVALID_INDEX ) 
                continue;

            array<string> SubLines = line.Split(",");
            array<double> SkillData = { atod(SubLines[1]), atod(SubLines[2]), atod(SubLines[3]), atod(SubLines[4]), atod(SubLines[5]), atod(SubLines[6]), atod(SubLines[7]), atod(SubLines[8]) };

            Skills.insertLast( SubLines[0] );
            SkillsMatrix.insertLast( SkillData );
        }

        pFile.Close();
    }

    void CheckEntitiesInThisMap()
    {
        EntitiesInThisMap.resize(0);

        for( int i = 0; i < g_Engine.maxEntities; ++i ) 
        {
            CBaseEntity@ ent = g_EntityFuncs.Instance( i );

            if( ent !is null ) 
            {
                if( ent.GetCustomKeyvalues().HasKeyvalue( "$i_dyndiff_skip" ) )
                    continue;
                
                if( ent.pev.health <= 0.0 || ent.pev.health >= 100000.0 )
                    continue;

                if( ent.IsMonster() && !ent.IsNetClient() && ent.IsAlive() )
                    EntitiesInThisMap.insertLast( ent );
            }
        }		
    }
    
    void ChangeVelocity()
    {
        ThinkChangeVelocity();
        g_barnacle.Think();
    }

    void ThinkChangeVelocity()
    {
        InitialMonsterSpeed = VoidMonsterSpeedMultiplier();

        if( InitialMonsterSpeed > 1.0 )
        {
            for( uint i = 0; i < EntitiesInThisMap.length(); ++i ) 
            {
                CBaseEntity@ monsters = cast<CBaseEntity@>( EntitiesInThisMap[i].GetEntity() );

                if( monsters !is null && !monsters.IsNetClient() && monsters.IsAlive() && monsters.pev.classname != "monster_barnacle" )
                {
                    monsters.pev.framerate = InitialMonsterSpeed;
                }
            }
        }

        g_Scheduler.SetTimeout( @this, "ThinkChangeVelocity", 0.1 );
    }

    void ChangeSkill()
    {
        for( uint i = 0; i < EntitiesInThisMap.length(); ++i ) 
        {
            CBaseEntity@ ent = cast<CBaseEntity@>( EntitiesInThisMap[i].GetEntity() );
            
            if( ent !is null && ent.IsMonster() && !ent.IsNetClient() && ent.IsAlive() ) 
            {
                if( ent.pev.classname == "monster_alien_babyvoltigore" )
                    ent.pev.health = SKValue(118)/3.0f;
                else if( ent.pev.classname == "monster_alien_controller" )
                    ent.pev.health = SKValue(37);
                else if( ent.pev.classname == "monster_alien_grunt" )
                    ent.pev.health = SKValue(0);
                else if( ent.pev.classname == "monster_alien_slave" )
                    ent.pev.health = SKValue(29);
                else if( ent.pev.classname == "monster_alien_tor" )
                    ent.pev.health = SKValue(114);
                else if( ent.pev.classname == "monster_alien_voltigore" )
                    ent.pev.health = SKValue(118);
                else if( ent.pev.classname == "monster_apache" )
                    ent.pev.health = SKValue(4);
                else if( ent.pev.classname == "monster_babycrab" )
                    ent.pev.health = SKValue(21)/3.0f;
                else if( ent.pev.classname == "monster_barnacle" )
                    ent.pev.health = SKValue(5);
                else if( ent.pev.classname == "monster_barney" )
                    ent.pev.health = SKValue(7);
                else if( ent.pev.classname == "monster_barney_dead" )
                    ent.pev.health = SKValue(7);
                else if( ent.pev.classname == "monster_bigmomma" )
                    ent.pev.health = SKValue(12);
                else if( ent.pev.classname == "monster_blkop_osprey" )
                    ent.pev.health = SKValue(123);
                else if( ent.pev.classname == "monster_blkop_apache" )
                    ent.pev.health = SKValue(4);
                else if( ent.pev.classname == "monster_bullchicken" )
                    ent.pev.health = SKValue(8);
                else if( ent.pev.classname == "monster_cleansuit_scientist" )
                    ent.pev.health = SKValue(43);
                else if( ent.pev.classname == "monster_gargantua" )
                    ent.pev.health = SKValue(16);
                else if( ent.pev.classname == "monster_gonome" )
                    ent.pev.health = SKValue(103);
                else if( ent.pev.classname == "monster_headcrab" )
                    ent.pev.health = SKValue(21);
                else if( ent.pev.classname == "monster_houndeye" )
                    ent.pev.health = SKValue(27);
                else if( ent.pev.classname == "monster_human_assassin" )
                    ent.pev.health = SKValue(20);
                else if( ent.pev.classname == "monster_human_grunt" )
                    ent.pev.health = SKValue(23);
                else if( ent.pev.classname == "monster_hwgrunt" )
                    ent.pev.health = SKValue(91);
                else if( ent.pev.classname == "monster_ichthyosaur" )
                    ent.pev.health = SKValue(33);
                else if( ent.pev.classname == "monster_kingpin" )
                    ent.pev.health = SKValue(127);
                else if( ent.pev.classname == "monster_leech" )
                    ent.pev.health = SKValue(35);
                else if( ent.pev.classname == "monster_male_assassin" )
                    ent.pev.health = SKValue(23);
                else if( ent.pev.classname == "monster_miniturret" )
                    ent.pev.health = SKValue(51);
                else if( ent.pev.classname == "monster_nihilanth" )
                    ent.pev.health = SKValue(41);
                else if( ent.pev.classname == "monster_osprey" )
                    ent.pev.health = SKValue(124);
                else if( ent.pev.classname == "monster_otis" )
                    ent.pev.health = SKValue(95);
                else if( ent.pev.classname == "monster_pitdrone" )
                    ent.pev.health = SKValue(107);
                else if( ent.pev.classname == "monster_scientist" )
                    ent.pev.health = SKValue(43);
                else if( ent.pev.classname == "monster_sentry" )
                    ent.pev.health = SKValue(52);
                else if( ent.pev.classname == "monster_shocktrooper" )
                    ent.pev.health = SKValue(111);
                else if( ent.pev.classname == "monster_snark" )
                    ent.pev.health = SKValue(44);
                else if( ent.pev.classname == "monster_sqknest" )
                    ent.pev.health = SKValue(126);
                else if( ent.pev.classname == "monster_stukabat" )
                    ent.pev.health = SKValue(125);
                else if( ent.pev.classname == "monster_tentacle" )
                    ent.pev.health = SKValue(122);
                else if( ent.pev.classname == "monster_turret" )
                    ent.pev.health = SKValue(50);
                else if( ent.pev.classname == "monster_zombie" )
                    ent.pev.health = SKValue(47);
                else if( ent.pev.classname == "monster_zombie_barney" )
                    ent.pev.health = SKValue(97);
                else if( ent.pev.classname == "monster_zombie_soldier" )
                    ent.pev.health = SKValue(100);
            }
        }

        for( uint i = 0; i < SkillsMatrix.size(); ++i )
        {
            g_EngineFuncs.CVarSetFloat(Skills[i], SKValue(i));
        }
    }

    void ChangeMaxHealth()
    {
        InitialMaxHealth = VoidPlayerMaxHealth();
        InitialMaxArmor = VoidPlayerMaxArmor();

        for( int iPlayer = 1; iPlayer <= g_Engine.maxClients; ++iPlayer )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayer );
        
            if( pPlayer is null || !pPlayer.IsConnected() )
                continue;

            if( pPlayer.pev.max_health < 1.0 ) pPlayer.pev.max_health = 1.0;
            if( pPlayer.pev.armortype < 1.0 ) pPlayer.pev.armortype = 1.0;	

            // if(pPlayer.pev.health > 0.0)
            //     pPlayer.pev.health *= InitialMaxHealth/h2 + 1.0;
            
            // if(pPlayer.pev.armorvalue > 0.0)
            //     pPlayer.pev.armorvalue *= InitialMaxArmor/a2 + 1.0;

            pPlayer.pev.max_health = InitialMaxHealth;
            pPlayer.pev.armortype = InitialMaxArmor;

            if( pPlayer.pev.health > pPlayer.pev.max_health )
                pPlayer.pev.health = pPlayer.pev.max_health;
            
            if( pPlayer.pev.armorvalue > pPlayer.pev.armortype )
                pPlayer.pev.armorvalue = pPlayer.pev.armortype;
        }
    }

    void Think()
    {   
        InitialMaxHealth = VoidPlayerMaxHealth();
        InitialMaxHealthCharge = VoidPlayerMaxHealthCharge();
        InitialMaxArmor = VoidPlayerMaxArmor();
        InitialMaxArmorCharge = VoidPlayerMaxArmorCharge();

        double BetweenTime = g_Engine.time - OldEngineTime;
        
        if( BetweenTime < 0.0 )
        {
            OldEngineTime = g_Engine.time;
        }
        else
        {
            if( !DisableDiff )
            {
                for( int iPlayer = 1; iPlayer <= g_Engine.maxClients; ++iPlayer )
                {
                    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayer );
                
                    if( pPlayer is null || !pPlayer.IsConnected() )
                        continue;
            
                    if( pPlayer.IsAlive() )
                    {
                        if( pPlayer.pev.health > 0.0 )
                        {
                            pPlayer.pev.max_health = InitialMaxHealth;
                            pPlayer.pev.armortype = InitialMaxArmor;

                            if( InitialMaxHealthCharge > 0.0  )
                                pPlayer.pev.health += InitialMaxHealthCharge * BetweenTime;
                            
                            if( InitialMaxArmorCharge > 0.0 )
                                pPlayer.pev.armorvalue += InitialMaxArmorCharge * BetweenTime;
                        }

                        if( pPlayer.pev.health > pPlayer.pev.max_health )
                            pPlayer.pev.health = pPlayer.pev.max_health;
                        
                        if( pPlayer.pev.armorvalue > pPlayer.pev.armortype )
                            pPlayer.pev.armorvalue = pPlayer.pev.armortype;
                    }
                }
            }
      
            OldEngineTime += BetweenTime;
        }
        
        g_Scheduler.SetTimeout( @this, "Think", 0.1);
    }

    void CheckPointDisabled()
    {
        if( NewDifficult != 1.0 )
            return;

        for( int i = 0; i < g_Engine.maxEntities; ++i ) 
        {
            CBaseEntity@ ent = g_EntityFuncs.Instance( i );
            
            if( ent is null || ent.GetCustomKeyvalues().HasKeyvalue( "$i_dyndiff_skip" ) || ent.pev.classname != "point_checkpoint" )
                continue;

            g_EntityFuncs.Remove( ent );		
        }
    }

    void IgnoreDyff()
    {
        File@ pFile = g_FileSystem.OpenFile( "scripts/plugins/store/DDX-Maplist.txt", OpenFile::READ );
        
        if( pFile is null || !pFile.IsOpen() ) 
            return;
        
        string MapName = string(g_Engine.mapname).ToLowercase();
        string ReadMapName = "";
        
        while( !pFile.EOFReached() )
        {
            pFile.ReadLine( ReadMapName );

            if( ReadMapName.Length() < 1 ) 
                continue;

            ReadMapName.ToLowercase();

            if( MapName == ReadMapName )
            {
                DisableDiff = true;
                return;
            }
            else
            {
                DisableDiff = false;
            }
        }

        pFile.Close();
    }

    string GetMessage()
    {
        int ChooseDiffInt = int(NewDifficult*1000.0);
        string aStr = "[SERVER] Difficulty: "+(ChooseDiffInt/10)+"."+(ChooseDiffInt%10)+"%%";

        string bStr = " ";
        string cStr = "";

        /*if( NewDifficult < 0.0005 ) bStr = " (Lowest Difficulty) ";
        else if( NewDifficult < 0.1 ) bStr = " (Beginners) ";
        else if( NewDifficult < 0.2 ) bStr = " (Very Easy) ";
        else if( NewDifficult < 0.4 ) bStr = " (Easy) ";
        else if( NewDifficult < 0.6 ) bStr = " (Medium) ";
        else if( NewDifficult < 0.75 ) bStr = " (Hard) ";
        else if( NewDifficult < 0.85 ) bStr = " (Very Hard!) ";
        else if( NewDifficult < 0.9 ) bStr = " (Extreme!) ";
        else if( NewDifficult < 0.95 ) bStr = " (Near Impossible!) ";
        else if( NewDifficult < 0.9995 ) bStr = " (Impossible!) ";
        else bStr = "(MAXIMUM DIFFICULTY!)";*/
             
        if( LastPlayerNum == 0 )
            cStr = "(Nobody was connected during Starting point)";
        else if( LastPlayerNum == 1 )
            cStr = "(A person connected during Starting point)";
        else
            cStr = "("+LastPlayerNum+" people were connected during Starting point)";

        if( !DisableDiff )
        {
            return aStr+bStr+cStr;
        }
        else
        {
            return "[SERVER] Difficulty: Disabled on this map";
        }
    }

    double MaxArray( array<double> MaxCapacity )
    {	
        if( NewDifficult == 1.0 )
        {
            return MaxCapacity[MaxCapacity.length()-1];
        }
        else
        {
            for( uint i = 0; i < DiffBorders.length();++i )
            {
                if( DiffBorders[i] == NewDifficult)
                {
                    return MaxCapacity[i];
                }
                else if( DiffBorders.length() > i && DiffBorders[i+1] > NewDifficult )
                {
                    double mino = DiffBorders[i];
                    double maxo = DiffBorders[i+1];
                    double difference = (NewDifficult-mino)/(maxo-mino);
                    
                    return MaxCapacity[i] * (1-difference) + MaxCapacity[i+1] * difference;
                }
            }
        }
        return -1.0;
    }

    double SKValue(int indexo)
    {
        if( NewDifficult == 1.0 )
        {
            return SkillsMatrix[indexo][7];
        }
        else
        {		
            for( uint i = 0; i < DiffBorders.length();++i )
            {
                if( DiffBorders[i] == NewDifficult)
                {
                    return SkillsMatrix[indexo][i];
                }
                else if( DiffBorders.length() > i && DiffBorders[i+1] > NewDifficult )
                {
                    double mino = DiffBorders[i];
                    double maxo = DiffBorders[i+1];
                    double difference = (NewDifficult-mino)/(maxo-mino);
                                        
                    return SkillsMatrix[indexo][i]*(1-difference) + SkillsMatrix[indexo][i+1]*difference;
                }	
            }	
        }
        return -1.0;
    }
}

final class Timer
{
    /***************************/
    /* Current name of the map */
    /***************************/
    string OldMap = "";

    /************************************************/
    /* How often does the same map needs to restart */
    /************************************************/
    int Fails = 0;

    /***************************/
    /* Current Time of the map */
    /***************************/
    private int TimerS = 0;
    private int TimerM = 0;
    private int TimerH = 0;
    private int TimerD = 0;

    /**************************************/
    /* CubePavo, idk what are you waiting */
    /**************************************/
    private bool CubePavo = false;

    Timer()
    {
        Fails = 0;

        TimerS = 0;
        TimerM = 0;
        TimerH = 0;
        TimerD = 0;

        CubePavo = false;

        Think();
    }

    void PluginInit()
    {
        if( OldMap != g_Engine.mapname )
        {
            OldMap = g_Engine.mapname;
        }

        if( g_Engine.time < 5.5f )
        {
            g_Scheduler.SetTimeout( @this, "PluginInit", 5.5f-g_Engine.time);
            return;
        }

        CubePavo = true;
    }

    void MapActivate()
    {
        if( CubePavo )
        {
            if( OldMap != g_Engine.mapname )
            {
                Fails = 0;
                TimerS = 0;
                TimerM = 0;
                TimerH = 0;
                TimerD = 0;

                OldMap = g_Engine.mapname;
            }
            else
            {
                ++Fails;
            }
        }
    }
    
    void Think()
    {   	
        if( TimerS == 60 )
        { ++TimerM; TimerS = 0; }

        if( TimerM == 60 )
        { ++TimerH; TimerM = 0; }

        if( TimerH == 24 )
        { ++TimerD; TimerH = 0; }
            
        ++TimerS;
    
        g_Scheduler.SetTimeout( @this, "Think", 1.0);
    }

    string GetMessage( int mode )
    {
        string S, M, H, D, Time;

        if( TimerS < 10 ) S = "0" + TimerS;
        else S = TimerS;
        
        if( TimerM < 10 ) M = "0" + TimerM;
        else M = TimerM;

        if( TimerH < 10 ) H = "0" + TimerH;
        else H = TimerH;

        if( TimerD < 10 ) D = "0" + TimerD;
        else D = TimerD;

        switch( mode )
        {
            case 0:	
            {
                Time = " (Timer: " +H+ ":" +M+ ":" +S+ ")"; break;
            }
            case 1: 
            {
                if( S != "00" ) Time = " (Timer: "+S+ "s)";
                if( M != "00" ) Time = " (Timer: "+M+"m"+S+"s)";
                if( H != "00" ) Time = " (Timer: "+H+"h"+M+"m"+S+"s)";
                if( D != "00" ) Time = " (Timer: "+H+"d"+H+"h"+M+"m"+S+"s)";

                break;
            }
        }

        return Time + " (Map restarted: " +Fails+ " times)";
    }
}

class PlayerVote 
{
    int ivote = 0;
    int ivotedelay = 120;
}

PlayerVote@ GetPlayerVote(CBasePlayer@ pPlayer)
{
    string SteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

    if( !g_Player_Spamming.exists(SteamID) )
    {
        PlayerVote state;
        g_Player_Spamming[SteamID] = state;
    }

    return cast<PlayerVote@>( g_Player_Spamming[SteamID] );
}

int FindSteamID(CBasePlayer@ pPlayer)
{
    string SteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

    return SteamIDArray.find( SteamID );
}

final class VoteAlt
{
    /***************************/
    /* Current Time of the map */
    /***************************/
    int DelayTimer = 0;

    /***********************/
    /* Difficulty Selected */
    /***********************/
    private double DiffSelected = 0;

    VoteAlt()
    {
        DelayTimer = 30;
        DiffSelected = 0;

        Think();
    }

    void Think()
    {   
        if( DelayTimer > 0 ) 
            --DelayTimer;

        for( int iPlayer = 1; iPlayer <= g_Engine.maxClients; ++iPlayer )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayer );
                
            if( pPlayer is null || !pPlayer.IsConnected() )
                continue;

            PlayerVote@ VoteState = GetPlayerVote(pPlayer);

            if( VoteState.ivote >= 4 ) 
                --VoteState.ivotedelay;
            else 
                VoteState.ivotedelay = 120;

            if( VoteState.ivotedelay == 0 ) 
                VoteState.ivote = 0;
        }

        g_Scheduler.SetTimeout( @this, "Think", 1.0);
    }

    void Vote( CBasePlayer@ pPlayer, string message ) 
    {
        DiffSelected = (atof(message)/100);
        g_Game.AlertMessage( at_console, string(DiffSelected)+'\n');

        if( DiffSelected < g_diffy.DiffBorders[0] ) DiffSelected = g_diffy.DiffBorders[0];
        if( DiffSelected > g_diffy.DiffBorders[g_diffy.DiffBorders.length()-1] ) DiffSelected = g_diffy.DiffBorders[g_diffy.DiffBorders.length()-1];
        if( DiffSelected < (g_diffy.DiffBorders[0]+0.001) && DiffSelected > g_diffy.DiffBorders[0] ) DiffSelected = (g_diffy.DiffBorders[0]+0.001);
        if( DiffSelected > (g_diffy.DiffBorders[g_diffy.DiffBorders.length()-1]-0.001) && DiffSelected < g_diffy.DiffBorders[g_diffy.DiffBorders.length()-1] ) DiffSelected = (g_diffy.DiffBorders[g_diffy.DiffBorders.length()-1]-0.001);

        int ChooseDiffInt = int(DiffSelected*1000.0);
        string Message = string(ChooseDiffInt/10)+"."+string(ChooseDiffInt%10)+"%%";

        const Cvar@ g_pCvarVoteAllow = g_EngineFuncs.CVarGetPointer( "mp_voteallow" );
        const Cvar@ g_pCvarVoteTimeCheck = g_EngineFuncs.CVarGetPointer( "mp_votetimecheck" );
        const Cvar@ g_pCvarVoteMapRequired = g_EngineFuncs.CVarGetPointer( "mp_votemaprequired" );
        PlayerVote@ VoteState = GetPlayerVote(pPlayer);

        if( g_pCvarVoteAllow !is null && g_pCvarVoteAllow.value < 1 )
        {
            g_PlayerFuncs.SayText( pPlayer, "Voting is disabled on this server.\n" );
            return;
        }

        if( g_pCvarVoteMapRequired.value < 0 )
        {
            g_PlayerFuncs.SayText( pPlayer, "This type of vote is disabled.\n" );
            return;
        }

        if( VoteState.ivote >= 4 )
        {
            g_PlayerFuncs.SayText( pPlayer, "Votes for you have been disabled. Wait "+VoteState.ivotedelay+" seconds.\n" );
            return;			
        }

        if( FindSteamID( pPlayer ) >= 0 )
        {
            g_PlayerFuncs.SayText( pPlayer, "Votes for you have been disabled. (PERMANENT)\n" );
            return;
        }

        if( DelayTimer > 0 )
        {
            g_PlayerFuncs.SayText( pPlayer, "Wait "+DelayTimer+" seconds to start another vote.\n" );
            return;
        }

        if( g_Utility.VoteActive() )
        {
            g_PlayerFuncs.SayText( pPlayer, "Cannot start this vote, another vote is in progress.\n" );
            return;
        }
        
        if( g_PlayerFuncs.GetNumPlayers() <= 1 )
        {
            DelayTimer = 30;

            g_diffy.SetNewDifficult(DiffSelected);

            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SERVER] Difficulty changed to "+Message+" by: "+pPlayer.pev.netname+"\n" );
            g_Game.AlertMessage( at_logged, "[SERVER] Difficulty changed to "+Message+" by: "+pPlayer.pev.netname+"\n" );
        }
        else
        {
            float flVoteTime = g_pCvarVoteTimeCheck.value;
            float flPercentage = g_pCvarVoteMapRequired.value;
            
            if( flVoteTime <= 0 )
                flVoteTime = 2;
            
            if( flPercentage <= 0 )
                flPercentage = 66;

            Vote customvote( "Difficulty Vote", "Change difficulty to " +Message+ "?", flVoteTime, flPercentage );
            customvote.SetYesText( "Yes");
            customvote.SetNoText( "No" );
            customvote.SetVoteBlockedCallback( FuncVoteBlocked(this.VoteBlocked) );
            customvote.SetVoteEndCallback( FuncVoteEnd(this.VoteEnd) );
            customvote.Start();
            
            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, customvote.GetName() + ": Started by " + pPlayer.pev.netname + "\n" );
            g_Game.AlertMessage( at_logged, customvote.GetName() + ": Started by " + pPlayer.pev.netname + "\n" );
        }

        ++VoteState.ivote;
    }

    void VoteEnd( Vote@ pVote, bool fResult, int iVoters )
    {
        DelayTimer = 30;

        if( fResult )
        {	
            g_diffy.SetNewDifficult(DiffSelected);

            NetworkMessage message( MSG_ALL, NetworkMessages::SVC_STUFFTEXT );
            message.WriteString( "spk buttons/bell1" );
            message.End();

            g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, "[SERVER] Difficulty: Vote to change the difficulty was successful!\n" );
            g_Game.AlertMessage( at_logged, "[SERVER] Difficulty: Vote to change the difficulty was successful!\n" );
        }
        else
        {
            g_PlayerFuncs.ClientPrintAll( HUD_PRINTNOTIFY, "[SERVER] Difficulty: Vote to change the difficulty was a failure :C\n" );
            g_Game.AlertMessage( at_logged, "[SERVER] Difficulty: Vote to change the difficulty was a failure :C\n" );
        }
    }

    void VoteBlocked(Vote@ pVote, float flTime)
    {
        g_Scheduler.SetTimeout( "Vote", flTime, false );
    }
}

final class BarnacleEatSpeed
{
    /****************************************/
    /* Current Speed of the barnacle tongue */
    /****************************************/
    private double InitialBarnacleSpeed = 8.0f;
    double VoidInitialBarnacleSpeed() { return InitialBarnacleSpeed; }

    /****************************/
    /* Barnacle speed eat array */
    /****************************/
    private array<double> BarnacleSpeed =
    {
        8.0, 8.0, 8.0, 8.0, 8.0, 18.0, 32.0, 48.0
    };
    double VoidBarnacleSpeed() { return g_diffy.MaxArray( BarnacleSpeed ); }

    BarnacleEatSpeed()
    {
        //Hola :D
    }

    void Think()
    {	
        InitialBarnacleSpeed = VoidBarnacleSpeed();

        if( InitialBarnacleSpeed > 8 )
        {
            for( uint i = 0; i < g_diffy.EntitiesInThisMap.length(); ++i ) 
            {
                CBaseMonster@ monsters = cast<CBaseMonster@>( g_diffy.EntitiesInThisMap[i].GetEntity() );

                if( monsters !is null && !monsters.IsNetClient() && monsters.IsAlive() && monsters.pev.classname == "monster_barnacle" )
                {
                    if( monsters.m_hEnemy.GetEntity() !is null && abs(monsters.pev.origin.z - ((monsters.m_hEnemy.GetEntity().pev.origin.z + monsters.m_hEnemy.GetEntity().pev.view_ofs.z) - 8)) >= 44 && monsters.m_Activity == ACT_RESET )
                    {
                        monsters.m_hEnemy.GetEntity().pev.origin.z += InitialBarnacleSpeed;
                    }	
                }
            }
        }

        g_Scheduler.SetTimeout( @this, "Think", 0.1 );
    }
}
