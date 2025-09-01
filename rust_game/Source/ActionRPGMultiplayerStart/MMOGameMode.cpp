#include "MMOGameMode.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"

AMMOGameMode::AMMOGameMode()
{
    // Set the default player controller class to our MMO Player Controller
    PlayerControllerClass = AMMOPlayerController::StaticClass();
    
    // Initialize connected player count
    ConnectedPlayerCount = 0;
    
    UE_LOG(LogTemp, Log, TEXT("🎮 MMO Game Mode initialized with MMO Player Controller"));
}

void AMMOGameMode::BeginPlay()
{
    Super::BeginPlay();
    
    UE_LOG(LogTemp, Log, TEXT("🌟 MMO Game Mode started - Ready for players!"));
}

void AMMOGameMode::PostLogin(APlayerController* NewPlayer)
{
    Super::PostLogin(NewPlayer);
    
    // Cast to MMO Player Controller
    AMMOPlayerController* MMOPlayer = Cast<AMMOPlayerController>(NewPlayer);
    if (MMOPlayer)
    {
        // Add to our list of MMO players
        MMOPlayerControllers.Add(MMOPlayer);
        ConnectedPlayerCount = MMOPlayerControllers.Num();
        
        UE_LOG(LogTemp, Log, TEXT("👤 MMO Player joined! Total players: %d"), ConnectedPlayerCount);
        
        // Force connection to MMO server if not auto-connecting
        if (!MMOPlayer->bAutoConnectToServer)
        {
            MMOPlayer->ConnectToMMOServer();
        }
    }
    else
    {
        UE_LOG(LogTemp, Warning, TEXT("⚠️ Player joined but is not using MMO Player Controller"));
    }
}

void AMMOGameMode::Logout(AController* Exiting)
{
    // Remove from MMO players list
    AMMOPlayerController* MMOPlayer = Cast<AMMOPlayerController>(Exiting);
    if (MMOPlayer)
    {
        MMOPlayerControllers.Remove(MMOPlayer);
        ConnectedPlayerCount = MMOPlayerControllers.Num();
        
        UE_LOG(LogTemp, Log, TEXT("👋 MMO Player left! Remaining players: %d"), ConnectedPlayerCount);
    }
    
    Super::Logout(Exiting);
}

TArray<AMMOPlayerController*> AMMOGameMode::GetConnectedMMOPlayers() const
{
    return MMOPlayerControllers;
}

void AMMOGameMode::BroadcastMessageToAllPlayers(const FString& Message)
{
    UE_LOG(LogTemp, Log, TEXT("📢 Broadcasting to %d players: %s"), MMOPlayerControllers.Num(), *Message);
    
    for (AMMOPlayerController* Player : MMOPlayerControllers)
    {
        if (Player && Player->IsValidLowLevel())
        {
            // You can add custom message handling here
            // For now, just log that we're sending to each player
            UE_LOG(LogTemp, VeryVerbose, TEXT("📤 Sending message to player: %s"), *Player->GetName());
        }
    }
}

void AMMOGameMode::TestMMOConnection()
{
    UE_LOG(LogTemp, Warning, TEXT("🧪 Testing MMO Connection..."));
    
    if (GEngine)
    {
        GEngine->AddOnScreenDebugMessage(-1, 10.0f, FColor::Yellow, TEXT("🧪 Testing MMO Connection..."));
    }
    
    // Try to get the first player controller and force a connection
    if (MMOPlayerControllers.Num() > 0)
    {
        AMMOPlayerController* TestPlayer = MMOPlayerControllers[0];
        if (TestPlayer)
        {
            UE_LOG(LogTemp, Warning, TEXT("🎮 Found MMO Player Controller, forcing connection..."));
            TestPlayer->ConnectToMMOServer();
        }
    }
    else
    {
        UE_LOG(LogTemp, Warning, TEXT("⚠️ No MMO Player Controllers found. Make sure you're playing the game!"));
        if (GEngine)
        {
            GEngine->AddOnScreenDebugMessage(-1, 10.0f, FColor::Red, TEXT("⚠️ No MMO Player Controllers found!"));
        }
    }
}