/* Entirely synthetic fixtures. No game, filesystem, network or player-save read. */
"use strict";
window.AZS_DEMO = Object.freeze({
  version: "2.0 · prototype",
  classes: ["Guerrier", "Voleur", "Mage", "Chasseur"],
  zones: {
    elwynn: "Forêt d’Elwynn", arena: "Arènes des Gurubashi", naxx: "Naxxramas",
    feralas: "Féralas", ungoro: "Cratère d’Un’Goro", sm: "Monastère Écarlate",
    av: "Vallée d’Alterac", ab: "Bassin Arathi", duskwood: "Bois de la Pénombre"
  },
  runs: [
    {id:"d12", zone:"arena", class:"Guerrier", heroic:3, mode:"Coop", players:3, result:"live", date:"30 oct. · 18:42", duration:934, level:42, kills:5682, gold:4125, damage:78200000, healing:48312, taken:89220, chests: null, affixes:["Sanguin"], coverage:94},
    {id:"d11", zone:"elwynn", class:"Guerrier", heroic:3, mode:"Solo", players:1, result:"victory", date:"30 oct. · 17:56", duration:1320, level:61, kills:14856, gold:9276, damage:293700000, healing:108231, taken:162044, chests:9, affixes:["Sanguin"], coverage:100},
    {id:"d10", zone:"naxx", class:"Mage", heroic:1, mode:"Coop", players:2, result:"defeat", date:"30 oct. · 16:38", duration:1187, level:54, kills:11287, gold:7052, damage:181200000, healing:18900, taken:65212, chests:7, affixes:[], coverage:91},
    {id:"d09", zone:"ungoro", class:"Chasseur", heroic:2, mode:"Solo", players:1, result:"victory", date:"29 oct. · 22:18", duration:1455, level:64, kills:16941, gold:11523, damage:350500000, healing:32500, taken:72450, chests:11, affixes:[], coverage:100},
    {id:"d08", zone:"arena", class:"Voleur", heroic:0, mode:"Solo", players:1, result:"victory", date:"29 oct. · 20:32", duration:1764, victoryAt:1200, hasEndless:true, level:72, kills:18920, gold:13482, damage:405600000, healing:145680, taken:149230, chests:12, affixes:[], coverage:100},
    {id:"d07", zone:"sm", class:"Guerrier", heroic:2, mode:"Coop", players:3, result:"victory", date:"29 oct. · 19:07", duration:1265, level:58, kills:10451, gold:6820, damage:206400000, healing:75633, taken:94212, chests:8, affixes:[], coverage:100},
    {id:"d06", zone:"elwynn", class:"Guerrier", heroic:3, mode:"Solo", players:1, result:"defeat", date:"28 oct. · 21:43", duration:1083, level:47, kills:8450, gold:5408, damage:132100000, healing:68300, taken:113622, chests:6, affixes:["Sanguin"], coverage:100},
    {id:"d05", zone:"feralas", class:"Voleur", heroic:1, mode:"Coop", players:2, result:"victory", date:"28 oct. · 20:12", duration:1592, level:68, kills:16585, gold:11792, damage:380500000, healing:184600, taken:191584, chests:10, affixes:[], coverage:100},
    {id:"d04", zone:"duskwood", class:"Mage", heroic:0, mode:"Solo", players:1, result:"left", date:"27 oct. · 19:54", duration:411, level:19, kills:1920, gold:1090, damage:7320000, healing:1240, taken:12432, chests:2, affixes:[], coverage:100},
    {id:"d03", zone:"ab", class:"Chasseur", heroic:1, mode:"Solo", players:1, result:"defeat", date:"27 oct. · 18:05", duration:1296, level:52, kills:11380, gold:7312, damage:192300000, healing:16200, taken:52400, chests:7, affixes:[], coverage:100},
    {id:"d02", zone:"av", class:"Guerrier", heroic:0, mode:"Coop", players:3, result:"victory", date:"26 oct. · 21:16", duration:1508, level:62, kills:13900, gold:9002, damage:297900000, healing:87600, taken:92260, chests:9, affixes:[], coverage:98},
    {id:"d01", zone:"elwynn", class:"Guerrier", heroic:1, mode:"Solo", players:1, result:"victory", date:"25 oct. · 20:33", duration:1389, level:57, kills:12542, gold:8136, damage:249100000, healing:112380, taken:114582, chests:8, affixes:[], coverage:100}
  ],
  spells: [
    {key:"tourbillon",name:"Tourbillon",share:39.2,glyph:2,rank:17,changes:16,runs:6},
    {key:"heurtoir",name:"Heurt de bouclier",share:24.6,glyph:16,rank:12,changes:11,runs:5},
    {key:"execute",name:"Exécution",share:16.8,glyph:2,rank:9,changes:8,runs:6},
    {key:"thunder",name:"Coup de tonnerre",share:10.4,glyph:12,rank:7,changes:6,runs:4},
    {key:"wounds",name:"Blessures profondes",share:6.1,glyph:2,rank:1,changes:0,runs:5,proc:true},
    {key:"melee",name:"Mêlée",share:2.9,glyph:2,rank:1,changes:0,runs:6}
  ],
  attributes: [
    ["Points de vie", "6 420", "+184", "hp"], ["Dégâts", "+286,4 %", "+38,0 %", "dmg"],
    ["Hâte", "+46,2 %", "+11,0 %", "cd"], ["Chances de critique", "38,6 %", "+7,0 %", "crit"],
    ["Dégâts critiques", "315,0 %", "+11,0 %", "cm"], ["Zone d’effet", "+83,0 %", "+11,0 %", "area"],
    ["Écho", "9,0 %", "+3,0 %", "echo"], ["Portée de ramassage", "8,2 yd", "+126,0 %", "pick"],
    ["Dégâts contre les élites", "+42,0 %", null, "big"], ["Dégâts d’exécution", "+18,0 %", null, "exe"],
    ["Dégâts contre ennemis contrôlés", "+24,0 %", null, "cc"], ["Vitesse des DoT", "+15,0 %", null, "doth"],
    ["Bonus d’or", "+37,0 %", "+11,0 %", "gold"], ["Vol de vie", "3,0 %", null, "lch"],
    ["Réduction des dégâts", "8,0 %", "+5,0 %", "arm"], ["Cibles supplémentaires", "+3", "+1", "cnt"],
    ["Vitesse de déplacement", "+28,0 %", "+17,0 %", "spd"], ["Régénération", "5,2 PV/s", "+2,1 PV/s", "reg"],
    ["Soin par victime", "12 PV", null, "heal"], ["Bonus d’expérience", "+15,0 %", null, "xp"],
    ["Chance", "+71,0 %", null, "luck"], ["Épines", "18,0 %", null, "thn"],
    ["Vies supplémentaires", "1", null, "liv"], ["Puissance des buffs", "+20,0 %", null, "bp"],
    ["Cumuls des DoT", "3", null, "dots"], ["Dégâts contre ennemis affectés", "+12,0 %", null, "dotd"],
    ["Dégâts sous bouclier", "+8,0 %", null, "shd"], ["Dégâts de mêlée", "+16,0 %", null, "auto"],
    ["Dégâts des familiers", "Non reçu", null, "pet"]
  ],
  equipment: [
    {key:"helm",name:"Heaume de cuirassé",slot:"Tête",stars:3,glyph:7,lines:["+38 points de vie", "Équipé : +1,8 % de chances de coup critique.","Équipé : -2,2 % de temps de recharge.","Régénère 0,3 points de vie par seconde."],source:"Référence de démonstration — tooltip natif à capturer en jeu"},
    {key:"shoulder",name:"Épaulières de cuirassé",slot:"Épaules",stars:3,glyph:16,lines:["+24 points de vie", "Équipé : +4,0 % de dégâts."]},
    {key:"chest",name:"Cuirasse de cuirassé",slot:"Torse",stars:3,glyph:16,lines:["+52 points de vie", "Équipé : +3,2 % de réduction des dégâts."]},
    {key:"amulet",name:"Amulette de la Faucheuse",slot:"Amulette · bijou de partie",glyph:9,lines:["Renforce les dégâts du sort associé.","Les variantes II, III, IV sont regroupées dans Tendances."]},
    {key:"justice",name:"Main de justice",slot:"Bijou · rang de partie III",glyph:8,lines:["Donne à vos sorts une chance de se lancer deux fois.","Description fictive du scénario : ne remplace pas un tooltip capturé."]},
    {key:"band",name:"Marque de l’Élu",slot:"Bijou · rang de partie II",glyph:11,lines:["Augmente votre chance.","Accessoire regroupé sous son identité, sans doublons de rang."]}
  ],
  journal: [
    {t:36,title:"Tourbillon rejoint votre build",detail:"Rang observé 1 · les choix de cartes ne sont pas exposés",kind:"spell"},
    {t:124,title:"Main de justice équipée",detail:"Changement d’emplacement observé · bijou de partie",kind:"gear"},
    {t:228,title:"Tourbillon : rang 5 → 6",detail:"Zone d’effet globale : +32 % → +47 % · changements simultanés, causalité non prouvée",kind:"spell"},
    {t:382,title:"Bonus d’or : +22 % → +37 %",detail:"Variation globale reçue du client · pas d’attribution à une carte précise",kind:"stats"},
    {t:574,title:"Heurt de bouclier : rang 8 → 9",detail:"Gain de rang observé",kind:"spell"},
    {t:816,title:"Écho : 6 % → 9 %",detail:"Nouvelle caractéristique de l’analyse V2 · scénario fictif",kind:"stats"}
  ],
  encounters: [
    {id:"b1",name:"Grande prêtresse Jeklik",t:180,end:224,state:"Terminée · observation",damage:8400000,glyph:5},
    {id:"b2",name:"Grande prêtresse Venoxis",t:420,end:479,state:"Terminée · observation",damage:19600000,glyph:5},
    {id:"b3",name:"Seigneur sanglant Mandokir",t:660,end:742,state:"Terminée · observation",damage:32400000,glyph:5},
    {id:"b4",name:"Jin’do le Maléficieur",t:900,end:null,state:"Rencontre en cours",damage:5600000,glyph:5}
  ],
  party: [
    {name:"Lockpin",class:"Chasseur",damage:103400000,dps:110706,top:"Salve",down:1,support:"Réanimation observée",glyph:2},
    {name:"Maiden",class:"Guerrier",damage:78200000,dps:83726,top:"Tourbillon",down:1,support:"Une tentative interrompue",glyph:7,self:true},
    {name:"Emp",class:"Démoniste",damage:68200000,dps:73019,top:"Pluie de feu",down:0,support:"Aucun événement observé",glyph:9}
  ],
  nemeses: [
    {id:"n1",name:"Berserker gurubashi",confirmed:1,probable:3,zone:"arena",last:"30 oct. · 18:53"},
    {id:"n2",name:"Vermine kobold",confirmed:0,probable:3,zone:"elwynn",last:"28 oct. · 21:59"},
    {id:"n3",name:"Garde de la Légion",confirmed:0,probable:2,zone:"naxx",last:"27 oct. · 18:26"}
  ],
  capabilities: [
    ["Historique, totaux, builds et favoris", "V1 conservé", "Données communes compatibles avec la V1 : même schéma et mêmes identifiants."],
    ["Caractéristiques avancées / part équipement", "API identifiée", "Champs natifs supplémentaires ; unités propres à chaque caractéristique."],
    ["Affixes Heroic", "À valider en jeu", "Champ sérialisé identifié. Format et renouvellement à confirmer avant activation."],
    ["Journal de chaque boss", "Observation partielle", "Frontières à vérifier ; pas de kill déduit d’une simple disparition."],
    ["Mises à terre et réanimations", "Observation partielle", "Transitions locales observées ; aucune mesure complète de tous les soins alliés."],
    ["Invocations, buffs et debuffs", "Échantillonné", "Présence observée, pas de compte exact des lancements ou d’uptime continu."],
    ["Marques, étoiles et bonus de set structurés", "Non disponibles", "Pas d’API structurée vérifiée. Une description capturée reste du texte."],
    ["Carte exacte choisie et effet causal", "Non disponible", "Le journal conserve les changements observés, sans inventer une décision de carte."],
    ["Coup fatal universel", "Non disponible", "Distinguer source confirmée et dernier attaquant probable."]
  ]
});
