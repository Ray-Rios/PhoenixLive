# EQEmu Database Import Script
# This script imports data from a real EQEmu database dump

alias PhoenixApp.Repo
alias PhoenixApp.EqemuGame

# Configuration for EQEmu database connection
eqemu_config = %{
  hostname: System.get_env("EQEMU_DB_HOST", "localhost"),
  username: System.get_env("EQEMU_DB_USER", "eqemu"),
  password: System.get_env("EQEMU_DB_PASS", "eqemu"),
  database: System.get_env("EQEMU_DB_NAME", "peq"),
  port: String.to_integer(System.get_env("EQEMU_DB_PORT", "3306"))
}

# Download and setup EQEmu database if not exists
setup_eqemu_database = fn ->
  IO.puts("Setting up EQEmu database...")
  
  # Download PEQ database (Project EQ - most popular EQEmu database)
  peq_url = "https://github.com/ProjectEQ/peqphpeditor/releases/download/latest/peq-dump.sql.gz"
  
  case System.cmd("wget", ["-O", "/tmp/peq-dump.sql.gz", peq_url]) do
    {_, 0} ->
      IO.puts("Downloaded PEQ database dump")
      
      # Extract the dump
      case System.cmd("gunzip", ["/tmp/peq-dump.sql.gz"]) do
        {_, 0} ->
          IO.puts("Extracted database dump")
          
          # Import into MySQL
          mysql_cmd = [
            "-h", eqemu_config.hostname,
            "-u", eqemu_config.username,
            "-p#{eqemu_config.password}",
            eqemu_config.database
          ]
          
          case System.cmd("mysql", mysql_cmd, stdin: File.read!("/tmp/peq-dump.sql")) do
            {_, 0} ->
              IO.puts("Successfully imported PEQ database")
              :ok
            {error, _} ->
              IO.puts("Failed to import database: #{error}")
              :error
          end
        {error, _} ->
          IO.puts("Failed to extract dump: #{error}")
          :error
      end
    {error, _} ->
      IO.puts("Failed to download PEQ database: #{error}")
      :error
  end
end

# Connect to EQEmu MySQL database
{:ok, eqemu_pid} = MyXQL.start_link(eqemu_config)

# Import functions
import_zones = fn ->
  IO.puts("Importing zones...")
  
  {:ok, %MyXQL.Result{rows: rows}} = MyXQL.query(eqemu_pid, """
    SELECT zoneidnumber, short_name, long_name, file_name, map_file_name,
           safe_x, safe_y, safe_z, safe_heading, graveyard_id, min_level,
           min_status, version, timezone, maxclients, ruleset, note,
           underworld, minclip, maxclip, fog_minclip, fog_maxclip,
           fog_blue, fog_red, fog_green, sky, ztype, zone_exp_multiplier,
           walkspeed, time_type, expansion
    FROM zone 
    WHERE expansion <= 2
    ORDER BY zoneidnumber
  """)
  
  Enum.each(rows, fn [zoneidnumber, short_name, long_name, file_name, map_file_name,
                     safe_x, safe_y, safe_z, safe_heading, graveyard_id, min_level,
                     min_status, version, timezone, maxclients, ruleset, note,
                     underworld, minclip, maxclip, fog_minclip, fog_maxclip,
                     fog_blue, fog_red, fog_green, sky, ztype, zone_exp_multiplier,
                     walkspeed, time_type, expansion] ->
    
    zone_attrs = %{
      zoneidnumber: zoneidnumber,
      short_name: short_name,
      long_name: long_name,
      file_name: file_name,
      map_file_name: map_file_name,
      safe_x: safe_x || 0.0,
      safe_y: safe_y || 0.0,
      safe_z: safe_z || 0.0,
      safe_heading: safe_heading || 0.0,
      graveyard_id: graveyard_id || 0.0,
      min_level: min_level || 1,
      min_status: min_status || 0,
      version: version || 0,
      timezone: timezone || 0,
      maxclients: maxclients || 0,
      ruleset: ruleset || 0,
      note: note,
      underworld: underworld || 0.0,
      minclip: minclip || 450.0,
      maxclip: maxclip || 450.0,
      fog_minclip: fog_minclip || 450.0,
      fog_maxclip: fog_maxclip || 450.0,
      fog_blue: fog_blue || 0,
      fog_red: fog_red || 0,
      fog_green: fog_green || 0,
      sky: sky || 1,
      ztype: ztype || 1,
      zone_exp_multiplier: zone_exp_multiplier || Decimal.new("0.00"),
      walkspeed: walkspeed || 0.4,
      time_type: time_type || 2,
      expansion: expansion || 0
    }
    
    EqemuGame.create_zone(zone_attrs)
  end)
  
  IO.puts("Imported #{length(rows)} zones")
end

import_items = fn ->
  IO.puts("Importing items...")
  
  {:ok, %MyXQL.Result{rows: rows}} = MyXQL.query(eqemu_pid, """
    SELECT id, name, lore, idfile, lorefile, nodrop, norent, nodonate,
           cantune, noswap, size, weight, itemtype, icon, price, sellrate,
           favor, guildfavor, pointtype, bagtype, bagslots, bagsize, bagwr,
           book, booktype, filename, banedmgrace, banedmgbody, banedmgamt,
           magic, casttime_, reqlevel, bardtype, bardvalue, light, delay,
           elemdmgtype, elemdmgamt, range_, damage, color, prestige, classes,
           races, deity, skillmodtype, skillmodvalue, banedmgraceamt,
           banedmgbodyamt, worntype, ac, accuracy, aagi, acha, adex, aint,
           asta, astr, awis, hp, mana, endur, atk, cr, dr, fr, mr, pr,
           svcorruption, haste, damageshield
    FROM items 
    WHERE reqlevel <= 65 AND itemtype IN (0,1,2,3,4,5,8,10,11,14,15,16,17,18,19,20,21,27,29,30,31,32,33,34,35,36,37,38,39,40,42,45)
    ORDER BY id
    LIMIT 10000
  """)
  
  Enum.each(rows, fn [id, name, lore, idfile, lorefile, nodrop, norent, nodonate,
                     cantune, noswap, size, weight, itemtype, icon, price, sellrate,
                     favor, guildfavor, pointtype, bagtype, bagslots, bagsize, bagwr,
                     book, booktype, filename, banedmgrace, banedmgbody, banedmgamt,
                     magic, casttime_, reqlevel, bardtype, bardvalue, light, delay,
                     elemdmgtype, elemdmgamt, range_, damage, color, prestige, classes,
                     races, deity, skillmodtype, skillmodvalue, banedmgraceamt,
                     banedmgbodyamt, worntype, ac, accuracy, aagi, acha, adex, aint,
                     asta, astr, awis, hp, mana, endur, atk, cr, dr, fr, mr, pr,
                     svcorruption, haste, damageshield] ->
    
    item_attrs = %{
      item_id: id,
      name: name,
      lore: lore,
      idfile: idfile,
      lorefile: lorefile,
      nodrop: nodrop || 0,
      norent: norent || 0,
      nodonate: nodonate || 0,
      cantune: cantune || 0,
      noswap: noswap || 0,
      size: size || 0,
      weight: weight || 0,
      item_type: itemtype || 0,
      icon: icon || 0,
      price: price || 0,
      sellrate: sellrate || 1.0,
      favor: favor || 0,
      guildfavor: guildfavor || 0,
      pointtype: pointtype || 0,
      bagtype: bagtype || 0,
      bagslots: bagslots || 0,
      bagsize: bagsize || 0,
      bagwr: bagwr || 0,
      book: book || 0,
      booktype: booktype || 0,
      filename: filename,
      banedmgrace: banedmgrace || 0,
      banedmgbody: banedmgbody || 0,
      banedmgamt: banedmgamt || 0,
      magic: magic || 0,
      casttime_: casttime_ || 0,
      reqlevel: reqlevel || 0,
      bardtype: bardtype || 0,
      bardvalue: bardvalue || 0,
      light: light || 0,
      delay: delay || 0,
      elemdmgtype: elemdmgtype || 0,
      elemdmgamt: elemdmgamt || 0,
      range_: range_ || 0,
      damage: damage || 0,
      color: color || 0,
      prestige: prestige || 0,
      classes: classes || 0,
      races: races || 0,
      deity: deity || 0,
      skillmodtype: skillmodtype || 0,
      skillmodvalue: skillmodvalue || 0,
      banedmgraceamt: banedmgraceamt || 0,
      banedmgbodyamt: banedmgbodyamt || 0,
      worntype: worntype || 0,
      ac: ac || 0,
      accuracy: accuracy || 0,
      aagi: aagi || 0,
      acha: acha || 0,
      adex: adex || 0,
      aint: aint || 0,
      asta: asta || 0,
      astr: astr || 0,
      awis: awis || 0,
      hp: hp || 0,
      mana: mana || 0,
      endur: endur || 0,
      atk: atk || 0,
      cr: cr || 0,
      dr: dr || 0,
      fr: fr || 0,
      mr: mr || 0,
      pr: pr || 0,
      svcorruption: svcorruption || 0,
      haste: haste || 0,
      damageshield: damageshield || 0
    }
    
    EqemuGame.create_item(item_attrs)
  end)
  
  IO.puts("Imported #{length(rows)} items")
end

import_npcs = fn ->
  IO.puts("Importing NPCs...")
  
  {:ok, %MyXQL.Result{rows: rows}} = MyXQL.query(eqemu_pid, """
    SELECT id, name, lastname, level, race, class, bodytype, hp, mana, gender,
           texture, helmtexture, herosforgemodel, size, hp_regen_rate, mana_regen_rate,
           loottable_id, merchant_id, alt_currency_id, npc_spells_id, npc_spells_effects_id,
           npc_faction_id, adventure_template_id, trap_template, mindmg, maxdmg,
           attack_count, npcspecialattks, special_abilities, aggroradius, assistradius,
           face, luclin_hairstyle, luclin_haircolor, luclin_eyecolor, luclin_eyecolor2,
           luclin_beardcolor, luclin_beard, drakkin_heritage, drakkin_tattoo, drakkin_details,
           armortint_id, armortint_red, armortint_green, armortint_blue, d_melee_texture1,
           d_melee_texture2, ammo_idfile, prim_melee_type, sec_melee_type, ranged_type,
           runspeed, MR, CR, DR, FR, PR, Corrup, PhR, see_invis, see_invis_undead,
           qglobal, AC, npc_aggro, spawn_limit, attack_speed, attack_delay, findable,
           STR, STA, DEX, AGI, _INT, WIS, CHA, see_hide, see_improved_hide, trackable,
           isbot, exclude, ATK, Accuracy, Avoidance, left_ring_idfile, right_ring_idfile,
           exp_pct, greed, engage_notice, ignore_despawn, avoidance_cap
    FROM npc_types 
    WHERE level <= 65
    ORDER BY id
    LIMIT 5000
  """)
  
  Enum.each(rows, fn [id, name, lastname, level, race, class, bodytype, hp, mana, gender,
                     texture, helmtexture, herosforgemodel, size, hp_regen_rate, mana_regen_rate,
                     loottable_id, merchant_id, alt_currency_id, npc_spells_id, npc_spells_effects_id,
                     npc_faction_id, adventure_template_id, trap_template, mindmg, maxdmg,
                     attack_count, npcspecialattks, special_abilities, aggroradius, assistradius,
                     face, luclin_hairstyle, luclin_haircolor, luclin_eyecolor, luclin_eyecolor2,
                     luclin_beardcolor, luclin_beard, drakkin_heritage, drakkin_tattoo, drakkin_details,
                     armortint_id, armortint_red, armortint_green, armortint_blue, d_melee_texture1,
                     d_melee_texture2, ammo_idfile, prim_melee_type, sec_melee_type, ranged_type,
                     runspeed, mr, cr, dr, fr, pr, corrup, phr, see_invis, see_invis_undead,
                     qglobal, ac, npc_aggro, spawn_limit, attack_speed, attack_delay, findable,
                     str, sta, dex, agi, int, wis, cha, see_hide, see_improved_hide, trackable,
                     isbot, exclude, atk, accuracy, avoidance, left_ring_idfile, right_ring_idfile,
                     exp_pct, greed, engage_notice, ignore_despawn, avoidance_cap] ->
    
    npc_attrs = %{
      npc_id: id,
      name: name,
      lastname: lastname,
      level: level || 1,
      race: race || 1,
      class: class || 1,
      bodytype: bodytype || 1,
      hp: hp || 100,
      mana: mana || 0,
      gender: gender || 0,
      texture: texture || 0,
      helmtexture: helmtexture || 0,
      herosforgemodel: herosforgemodel || 0,
      size: size || 6.0,
      hp_regen_rate: hp_regen_rate || 1,
      mana_regen_rate: mana_regen_rate || 1,
      loottable_id: loottable_id || 0,
      merchant_id: merchant_id || 0,
      alt_currency_id: alt_currency_id || 0,
      npc_spells_id: npc_spells_id || 0,
      npc_spells_effects_id: npc_spells_effects_id || 0,
      npc_faction_id: npc_faction_id || 0,
      adventure_template_id: adventure_template_id || 0,
      trap_template: trap_template || 0,
      mindmg: mindmg || 1,
      maxdmg: maxdmg || 1,
      attack_count: attack_count || -1,
      npcspecialattks: npcspecialattks,
      special_abilities: special_abilities,
      aggroradius: aggroradius || 70,
      assistradius: assistradius || 0,
      face: face || 1,
      luclin_hairstyle: luclin_hairstyle || 1,
      luclin_haircolor: luclin_haircolor || 1,
      luclin_eyecolor: luclin_eyecolor || 1,
      luclin_eyecolor2: luclin_eyecolor2 || 1,
      luclin_beardcolor: luclin_beardcolor || 1,
      luclin_beard: luclin_beard || 0,
      drakkin_heritage: drakkin_heritage || 0,
      drakkin_tattoo: drakkin_tattoo || 0,
      drakkin_details: drakkin_details || 0,
      armortint_id: armortint_id || 0,
      armortint_red: armortint_red || 0,
      armortint_green: armortint_green || 0,
      armortint_blue: armortint_blue || 0,
      d_melee_texture1: d_melee_texture1 || 0,
      d_melee_texture2: d_melee_texture2 || 0,
      ammo_idfile: ammo_idfile || "IT10",
      prim_melee_type: prim_melee_type || 28,
      sec_melee_type: sec_melee_type || 28,
      ranged_type: ranged_type || 7,
      runspeed: runspeed || 1.25,
      mr: mr || 0,
      cr: cr || 0,
      dr: dr || 0,
      fr: fr || 0,
      pr: pr || 0,
      corrup: corrup || 0,
      phr: phr || 0,
      see_invis: see_invis || 0,
      see_invis_undead: see_invis_undead || 0,
      qglobal: qglobal || 0,
      ac: ac || 0,
      npc_aggro: npc_aggro || 0,
      spawn_limit: spawn_limit || 0,
      attack_speed: attack_speed || 0.0,
      attack_delay: attack_delay || 30,
      findable: findable || 0,
      str: str || 75,
      sta: sta || 75,
      dex: dex || 75,
      agi: agi || 75,
      int: int || 80,
      wis: wis || 75,
      cha: cha || 75,
      see_hide: see_hide || 0,
      see_improved_hide: see_improved_hide || 0,
      trackable: trackable || 1,
      isbot: isbot || 0,
      exclude: exclude || 1,
      atk: atk || 0,
      accuracy: accuracy || 0,
      avoidance: avoidance || 0,
      left_ring_idfile: left_ring_idfile || "IT10",
      right_ring_idfile: right_ring_idfile || "IT10",
      exp_pct: exp_pct || 100,
      greed: greed || 0,
      engage_notice: engage_notice || 0,
      ignore_despawn: ignore_despawn || 0,
      avoidance_cap: avoidance_cap || 0
    }
    
    EqemuGame.create_npc(npc_attrs)
  end)
  
  IO.puts("Imported #{length(rows)} NPCs")
end

import_spells = fn ->
  IO.puts("Importing spells...")
  
  {:ok, %MyXQL.Result{rows: rows}} = MyXQL.query(eqemu_pid, """
    SELECT id, name, player_1, teleport_zone, you_cast, other_casts, cast_on_you,
           cast_on_other, spell_fades, range_, aoerange, pushback, pushup, cast_time,
           recovery_time, recast_time, buffdurationformula, buffduration, AEDuration,
           mana, effect_base_value1, effect_base_value2, effect_base_value3,
           effect_base_value4, effect_base_value5, effect_base_value6,
           effect_base_value7, effect_base_value8, effect_base_value9,
           effect_base_value10, effect_base_value11, effect_base_value12,
           icon, memicon, components1, components2, components3, components4,
           component_counts1, component_counts2, component_counts3, component_counts4,
           NoexpendReagent1, NoexpendReagent2, NoexpendReagent3, NoexpendReagent4,
           formula1, formula2, formula3, formula4, formula5, formula6,
           formula7, formula8, formula9, formula10, formula11, formula12,
           LightType, goodEffect, Activated, resisttype, effectid1, effectid2,
           effectid3, effectid4, effectid5, effectid6, effectid7, effectid8,
           effectid9, effectid10, effectid11, effectid12, targettype, basediff,
           skill, zonetype, EnvironmentType, TimeOfDay, classes1, classes2,
           classes3, classes4, classes5, classes6, classes7, classes8,
           classes9, classes10, classes11, classes12, classes13, classes14,
           classes15, classes16, CastingAnim, TargetAnim, TravelType,
           SpellAffectIndex, disallow_sit
    FROM spells_new 
    WHERE classes1 <= 65 OR classes2 <= 65 OR classes3 <= 65 OR classes4 <= 65
    ORDER BY id
    LIMIT 3000
  """)
  
  Enum.each(rows, fn [id, name, player_1, teleport_zone, you_cast, other_casts, cast_on_you,
                     cast_on_other, spell_fades, range_, aoerange, pushback, pushup, cast_time,
                     recovery_time, recast_time, buffdurationformula, buffduration, aeduration,
                     mana, effect_base_value1, effect_base_value2, effect_base_value3,
                     effect_base_value4, effect_base_value5, effect_base_value6,
                     effect_base_value7, effect_base_value8, effect_base_value9,
                     effect_base_value10, effect_base_value11, effect_base_value12,
                     icon, memicon, components1, components2, components3, components4,
                     component_counts1, component_counts2, component_counts3, component_counts4,
                     noexpendreagent1, noexpendreagent2, noexpendreagent3, noexpendreagent4,
                     formula1, formula2, formula3, formula4, formula5, formula6,
                     formula7, formula8, formula9, formula10, formula11, formula12,
                     lighttype, goodeffect, activated, resisttype, effectid1, effectid2,
                     effectid3, effectid4, effectid5, effectid6, effectid7, effectid8,
                     effectid9, effectid10, effectid11, effectid12, targettype, basediff,
                     skill, zonetype, environmenttype, timeofday, classes1, classes2,
                     classes3, classes4, classes5, classes6, classes7, classes8,
                     classes9, classes10, classes11, classes12, classes13, classes14,
                     classes15, classes16, castinganim, targetanim, traveltype,
                     spellaffectindex, disallow_sit] ->
    
    spell_attrs = %{
      spell_id: id,
      name: name,
      player_1: player_1 || "BLUE_TRAIL",
      teleport_zone: teleport_zone,
      you_cast: you_cast,
      other_casts: other_casts,
      cast_on_you: cast_on_you,
      cast_on_other: cast_on_other,
      spell_fades: spell_fades,
      range_: range_ || 100,
      aoerange: aoerange || 0,
      pushback: pushback || 0.0,
      pushup: pushup || 0.0,
      cast_time: cast_time || 0,
      recovery_time: recovery_time || 0,
      recast_time: recast_time || 0,
      buffdurationformula: buffdurationformula || 7,
      buffduration: buffduration || 65,
      aeduration: aeduration || 0,
      mana: mana || 0,
      effect_base_value1: effect_base_value1 || 100,
      effect_base_value2: effect_base_value2 || 0,
      effect_base_value3: effect_base_value3 || 0,
      effect_base_value4: effect_base_value4 || 0,
      effect_base_value5: effect_base_value5 || 0,
      effect_base_value6: effect_base_value6 || 0,
      effect_base_value7: effect_base_value7 || 0,
      effect_base_value8: effect_base_value8 || 0,
      effect_base_value9: effect_base_value9 || 0,
      effect_base_value10: effect_base_value10 || 0,
      effect_base_value11: effect_base_value11 || 0,
      effect_base_value12: effect_base_value12 || 0,
      icon: icon || 0,
      memicon: memicon || 0,
      components1: components1 || -1,
      components2: components2 || -1,
      components3: components3 || -1,
      components4: components4 || -1,
      component_counts1: component_counts1 || 1,
      component_counts2: component_counts2 || 1,
      component_counts3: component_counts3 || 1,
      component_counts4: component_counts4 || 1,
      noexpendreagent1: noexpendreagent1 || -1,
      noexpendreagent2: noexpendreagent2 || -1,
      noexpendreagent3: noexpendreagent3 || -1,
      noexpendreagent4: noexpendreagent4 || -1,
      formula1: formula1 || 100,
      formula2: formula2 || 100,
      formula3: formula3 || 100,
      formula4: formula4 || 100,
      formula5: formula5 || 100,
      formula6: formula6 || 100,
      formula7: formula7 || 100,
      formula8: formula8 || 100,
      formula9: formula9 || 100,
      formula10: formula10 || 100,
      formula11: formula11 || 100,
      formula12: formula12 || 100,
      lighttype: lighttype || 0,
      goodeffect: goodeffect || 0,
      activated: activated || 0,
      resisttype: resisttype || 0,
      effectid1: effectid1 || 254,
      effectid2: effectid2 || 254,
      effectid3: effectid3 || 254,
      effectid4: effectid4 || 254,
      effectid5: effectid5 || 254,
      effectid6: effectid6 || 254,
      effectid7: effectid7 || 254,
      effectid8: effectid8 || 254,
      effectid9: effectid9 || 254,
      effectid10: effectid10 || 254,
      effectid11: effectid11 || 254,
      effectid12: effectid12 || 254,
      targettype: targettype || 2,
      basediff: basediff || 0,
      skill: skill || 98,
      zonetype: zonetype || -1,
      environmenttype: environmenttype || 0,
      timeofday: timeofday || 0,
      classes1: classes1 || 255,
      classes2: classes2 || 255,
      classes3: classes3 || 255,
      classes4: classes4 || 255,
      classes5: classes5 || 255,
      classes6: classes6 || 255,
      classes7: classes7 || 255,
      classes8: classes8 || 255,
      classes9: classes9 || 255,
      classes10: classes10 || 255,
      classes11: classes11 || 255,
      classes12: classes12 || 255,
      classes13: classes13 || 255,
      classes14: classes14 || 255,
      classes15: classes15 || 255,
      classes16: classes16 || 255,
      castinganim: castinganim || 44,
      targetanim: targetanim || 13,
      traveltype: traveltype || 0,
      spellaffectindex: spellaffectindex || -1,
      disallow_sit: disallow_sit || 0
    }
    
    EqemuGame.create_spell(spell_attrs)
  end)
  
  IO.puts("Imported #{length(rows)} spells")
end

import_tasks = fn ->
  IO.puts("Importing tasks (quests)...")
  
  {:ok, %MyXQL.Result{rows: rows}} = MyXQL.query(eqemu_pid, """
    SELECT id, type, duration, duration_code, title, description, reward,
           rewardid, cashreward, xpreward, rewardmethod, reward_radiant_crystals,
           reward_ebon_crystals, minlevel, maxlevel, level_spread, min_players,
           max_players, repeatable, faction_reward, completion_emote,
           replay_timer_seconds, request_timer_seconds
    FROM tasks 
    WHERE minlevel <= 65
    ORDER BY id
    LIMIT 1000
  """)
  
  Enum.each(rows, fn [id, type, duration, duration_code, title, description, reward,
                     rewardid, cashreward, xpreward, rewardmethod, reward_radiant_crystals,
                     reward_ebon_crystals, minlevel, maxlevel, level_spread, min_players,
                     max_players, repeatable, faction_reward, completion_emote,
                     replay_timer_seconds, request_timer_seconds] ->
    
    task_attrs = %{
      task_id: id,
      type: type || 0,
      duration: duration || 0,
      duration_code: duration_code || 0,
      title: title,
      description: description,
      reward: reward,
      rewardid: rewardid || 0,
      cashreward: cashreward || 0,
      xpreward: xpreward || 0,
      rewardmethod: rewardmethod || 2,
      reward_radiant_crystals: reward_radiant_crystals || 0,
      reward_ebon_crystals: reward_ebon_crystals || 0,
      minlevel: minlevel || 1,
      maxlevel: maxlevel || 65,
      level_spread: level_spread || 0,
      min_players: min_players || 0,
      max_players: max_players || 0,
      repeatable: repeatable || 1,
      faction_reward: faction_reward || 0,
      completion_emote: completion_emote,
      replay_timer_seconds: replay_timer_seconds || 0,
      request_timer_seconds: request_timer_seconds || 0
    }
    
    EqemuGame.create_task(task_attrs)
  end)
  
  IO.puts("Imported #{length(rows)} tasks")
end

# Run the import
IO.puts("Starting EQEmu data import...")

# Setup database if needed
case setup_eqemu_database.() do
  :ok ->
    IO.puts("Database setup complete")
  :error ->
    IO.puts("Database setup failed, continuing with existing data...")
end

# Import data
try do
  import_zones.()
  import_items.()
  import_npcs.()
  import_spells.()
  import_tasks.()
  
  IO.puts("EQEmu data import completed successfully!")
rescue
  e ->
    IO.puts("Import failed: #{inspect(e)}")
    IO.puts("Make sure you have:")
    IO.puts("1. MySQL server running")
    IO.puts("2. EQEmu database accessible")
    IO.puts("3. Proper credentials in environment variables")
end

# Close connection
MyXQL.stop(eqemu_pid)

IO.puts("Import script finished.")