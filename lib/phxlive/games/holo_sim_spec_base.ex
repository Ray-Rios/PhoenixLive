defmodule Phxlive.Games.HoloSimSpec.Base do
  @moduledoc """
  The solar-system template every Holo-sim system is generated from.

  GENERATED from `RaysSpaceSim/Saved/Systems/demo5_system.json` (the export of
  `Scripts/build_cosmos.py`) on 2026-10-08. It is an Elixir literal rather than
  a JSON file read at boot so the generator has no file or decoder dependency
  and can be exercised from a bare `elixir` shell.

  `SystemId`, `DisplayName`, `Seed` and `Metadata` are deliberately absent:
  `Phxlive.Games.HoloSimSpec` owns those. Everything a player chooses at
  creation is overwritten there; everything else (materials, meshes, station,
  sun, star field) comes from here unchanged.

  If `build_cosmos.py` changes the shared world, regenerate this - the two are
  meant to match, and nothing checks that they do.
  """

  def system do
    %{
      "Scale" => 1.0,
      "Arena" => %{
        "bSpawnArenaManager" => true,
        "Radius" => 4687500.0,
        "WallRestitution" => 0.95,
        "CenterPull" => 40.0,
        "SunClearance" => 50000.0
      },
      "PlanetField" => %{
        "Count" => 100,
        "MinRadius" => 28125.0,
        "MaxRadius" => 375000.0,
        "InnerFraction" => 0.14,
        "OuterFraction" => 0.9,
        "BreakVelocity" => 10000.0,
        "AtmosphereChance" => 1.0,
        "SurfaceGravity" => 980.0,
        "ShapeWeights" => [
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "I",
            "Weight" => 556
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "O",
            "Weight" => 833
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "T",
            "Weight" => 833
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "S",
            "Weight" => 556
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "Z",
            "Weight" => 556
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "J",
            "Weight" => 833
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "L",
            "Weight" => 833
          },
          %{
            "DieShape" => "D6",
            "TetrominoShape" => "None",
            "Weight" => 1250
          },
          %{
            "DieShape" => "D12",
            "TetrominoShape" => "None",
            "Weight" => 833
          },
          %{
            "DieShape" => "D20",
            "TetrominoShape" => "None",
            "Weight" => 833
          },
          %{
            "DieShape" => "D8",
            "TetrominoShape" => "None",
            "Weight" => 417
          },
          %{
            "DieShape" => "D4",
            "TetrominoShape" => "None",
            "Weight" => 417
          },
          %{
            "DieShape" => "Sphere",
            "TetrominoShape" => "None",
            "Weight" => 1250
          }
        ],
        "PlanetMaterial" => "/Game/CosmicDemo/Materials/M_Terra.M_Terra",
        "BlockMesh" => "/Engine/BasicShapes/Cube.Cube",
        "BlockMaterial" => "/Game/CosmicDemo/Materials/M_Terra.M_Terra",
        "PlanetMaterials" => [
          "/Game/AutomotiveMaterials/Materials/Exterior/Metal/MI_Metal_Chrome_01.MI_Metal_Chrome_01",
          "/Game/AutomotiveMaterials/Materials/Exterior/Metal/MI_Metal_Gold.MI_Metal_Gold",
          "/Game/AutomotiveMaterials/Materials/Exterior/Metal/MI_Metal_Steel.MI_Metal_Steel",
          "/Game/AutomotiveMaterials/Materials/Exterior/Metal/MI_Metal_Brushed.MI_Metal_Brushed",
          "/Game/AutomotiveMaterials/Materials/Exterior/Metal/MI_Metal_Brass.MI_Metal_Brass",
          "/Game/AutomotiveMaterials/Materials/Exterior/Metal/MI_Metal_Anodized_01.MI_Metal_Anodized_01",
          "/Game/AutomotiveMaterials/Materials/Exterior/Glass/MI_Glass_Tinted.MI_Glass_Tinted"
        ],
        "AtmosphereTints" => [
          %{
            "Name" => "Blue",
            "Color" => %{
              "R" => 0.2,
              "G" => 0.45,
              "B" => 1.0,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Green",
            "Color" => %{
              "R" => 0.2,
              "G" => 0.9,
              "B" => 0.45,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Red",
            "Color" => %{
              "R" => 0.9,
              "G" => 0.18,
              "B" => 0.12,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Yellow",
            "Color" => %{
              "R" => 1.0,
              "G" => 0.88,
              "B" => 0.25,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Orange",
            "Color" => %{
              "R" => 1.0,
              "G" => 0.5,
              "B" => 0.08,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Pink",
            "Color" => %{
              "R" => 1.0,
              "G" => 0.45,
              "B" => 0.7,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Lavender",
            "Color" => %{
              "R" => 0.72,
              "G" => 0.68,
              "B" => 1.0,
              "A" => 1.0
            }
          },
          %{
            "Name" => "Purple",
            "Color" => %{
              "R" => 0.55,
              "G" => 0.22,
              "B" => 0.9,
              "A" => 1.0
            }
          }
        ],
        "AtmosphereMaterial" => "/Game/CosmicDemo/Materials/M_Atmosphere.M_Atmosphere",
        "AtmosphereShellScale" => 1.12,
        "bScaleAtmosphereChanceWithRadius" => false,
        "EnemyPatrolAtmosphere" => "Red",
        "EnemyPatrolRadiusMultiplier" => 3.0,
        "EnemyPatrolFightersPerWave" => 3,
        "EnemyPatrolMaxActive" => 6,
        "EnemyPatrolWaveInterval" => 30.0,
        "DieMeshes" => [
          %{
            "Shape" => "D6",
            "Mesh" => "/Game/DiceDemo/Meshes/SM_Die_D6.SM_Die_D6"
          },
          %{
            "Shape" => "D12",
            "Mesh" => "/Game/DiceDemo/Meshes/SM_Die_D12.SM_Die_D12"
          },
          %{
            "Shape" => "D20",
            "Mesh" => "/Game/DiceDemo/Meshes/SM_Die_D20.SM_Die_D20"
          },
          %{
            "Shape" => "D8",
            "Mesh" => "/Game/DiceDemo/Meshes/SM_Die_D8.SM_Die_D8"
          },
          %{
            "Shape" => "D4",
            "Mesh" => "/Game/DiceDemo/Meshes/SM_Die_D4.SM_Die_D4"
          },
          %{
            "Shape" => "Sphere",
            "Mesh" => "/Game/DiceDemo/Meshes/SM_Die_Sphere.SM_Die_Sphere"
          }
        ],
        "FallbackDieMesh" => "/Game/CosmicDemo/Meshes/SM_PlanetSphere.SM_PlanetSphere",
        "SunKeepOutMultiplier" => 3.0,
        "PadWellClearanceMultiplier" => 3.0
      },
      "Spawn" => %{
        "Offset" => %{
          "X" => 0.0,
          "Y" => 0.0,
          "Z" => 393750.0
        },
        "KeepOutRadius" => 0.0
      },
      "Station" => %{
        "bEnabled" => true,
        "HullRadius" => 60000.0,
        "SlotHalfHeight" => 15000.0,
        "PolarShaftRadius" => 15000.0,
        "PylonCount" => 8,
        "DockingArmCount" => 6,
        "bSecondaryModule" => true,
        "HullBlockCount" => 6000,
        "PanelCount" => 900,
        "GreebleClusterCount" => 320,
        "WindowFraction" => 0.34,
        "AntennaCount" => 44,
        "DeckClutterCount" => 90,
        "LandingPadCount" => 7,
        "bBuildHoloSimEntrance" => true,
        "bSpawnHoloSimDoor" => true,
        "Seed" => 20260811,
        "HullMaterial" => "/Game/CosmicDemo/Materials/M_StationHull.M_StationHull",
        "PanelMaterial" => "/Game/CosmicDemo/Materials/M_StationPanel.M_StationPanel",
        "GreebleMaterial" => "/Game/CosmicDemo/Materials/M_StationGreeble.M_StationGreeble",
        "WindowMaterial" => "/Game/CosmicDemo/Materials/M_StationWindow.M_StationWindow",
        "BeaconMaterial" => "/Game/CosmicDemo/Materials/M_StationBeacon.M_StationBeacon",
        "StructureMaterial" => "/Game/CosmicDemo/Materials/M_StationStructure.M_StationStructure",
        "DeckMaterial" => "/Game/CosmicDemo/Materials/M_StationDeck.M_StationDeck",
        "ContainmentMaterial" => ""
      },
      "StarField" => %{
        "bEnabled" => true,
        "StarCount" => 2500,
        "ShellRadius" => 1800000000.0,
        "StarSizeRange" => %{
          "X" => 400000.0,
          "Y" => 1600000.0
        },
        "Seed" => 99,
        "StarMesh" => "/Engine/BasicShapes/Sphere.Sphere",
        "StarMaterial" => "/Game/CosmicDemo/Materials/M_Star.M_Star"
      },
      "FixedBodies" => [
        %{
          "Name" => "PoolSun",
          "Type" => "Star",
          "Location" => %{
            "X" => 0.0,
            "Y" => 0.0,
            "Z" => 0.0
          },
          "Radius" => 112500.0,
          "Mesh" => "/Game/CosmicDemo/Meshes/SM_PlanetSphere.SM_PlanetSphere",
          "OrbitalGM" => 75000000000000000.0,
          "SurfaceGravity" => 1200.0,
          "bPinned" => true,
          "InitialVelocity" => %{
            "X" => 0.0,
            "Y" => 0.0,
            "Z" => 0.0
          },
          "bHasAtmosphere" => false,
          "SurfaceMaterial" => "/Game/CosmicDemo/Materials/M_Lava.M_Lava",
          "ShellMaterial" => "",
          "ShellScale" => 1.0
        }
      ]
    }
  end
end
