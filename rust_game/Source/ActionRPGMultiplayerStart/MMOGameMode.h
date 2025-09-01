#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "MMOPlayerController.h"
#include "MMOGameMode.generated.h"

/**
 * MMO Game Mode that automatically uses the MMO Player Controller
 * This ensures all players get the MMO functionality automatically
 */
UCLASS(BlueprintType, Blueprintable)
class ACTIONRPGMULTIPLAYERSTART_API AMMOGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    AMMOGameMode();

protected:
    virtual void BeginPlay() override;
    
    // Called when a player joins the game
    virtual void PostLogin(APlayerController* NewPlayer) override;
    
    // Called when a player leaves the game
    virtual void Logout(AController* Exiting) override;

public:
    // Number of players currently connected
    UPROPERTY(BlueprintReadOnly, Category = "MMO")
    int32 ConnectedPlayerCount;
    
    // Get all connected MMO players
    UFUNCTION(BlueprintCallable, Category = "MMO")
    TArray<AMMOPlayerController*> GetConnectedMMOPlayers() const;
    
    // Broadcast a message to all connected players
    UFUNCTION(BlueprintCallable, Category = "MMO")
    void BroadcastMessageToAllPlayers(const FString& Message);
    
    // Test MMO connection (for debugging)
    UFUNCTION(BlueprintCallable, Category = "MMO", CallInEditor = true)
    void TestMMOConnection();

private:
    // Keep track of all MMO player controllers
    UPROPERTY()
    TArray<AMMOPlayerController*> MMOPlayerControllers;
};