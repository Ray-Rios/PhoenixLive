#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/VerticalBox.h"
#include "MMOPlayerController.h"
#include "MMOStatusWidget.generated.h"

UCLASS(BlueprintType, Blueprintable)
class ACTIONRPGMULTIPLAYERSTART_API UMMOStatusWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    virtual void NativeConstruct() override;
    virtual void NativeTick(const FGeometry& MyGeometry, float InDeltaTime) override;

protected:
    // UI Components (bind these in Blueprint)
    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UTextBlock* ServerStatusText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UTextBlock* SessionIDText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UTextBlock* OnlinePlayersText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UTextBlock* PlayerStatsText;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UButton* ConnectButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UButton* DisconnectButton;

    UPROPERTY(BlueprintReadOnly, meta = (BindWidget))
    class UVerticalBox* OnlinePlayersBox;

    // Settings
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "MMO UI")
    float UpdateInterval = 1.0f;

public:
    // Functions callable from Blueprint
    UFUNCTION(BlueprintCallable, Category = "MMO UI")
    void UpdateServerStatus();

    UFUNCTION(BlueprintCallable, Category = "MMO UI")
    void UpdateOnlinePlayersList();

    UFUNCTION(BlueprintCallable, Category = "MMO UI")
    void UpdatePlayerStats();

    // Button event handlers
    UFUNCTION()
    void OnConnectButtonClicked();

    UFUNCTION()
    void OnDisconnectButtonClicked();

private:
    // Reference to MMO Player Controller
    UPROPERTY()
    AMMOPlayerController* MMOPlayerController;

    // Update timer
    float LastUpdateTime = 0.0f;

    void FindMMOPlayerController();
    FString FormatPlayerStats(const FPlayerData& PlayerData) const;
};