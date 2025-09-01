#include "MMOStatusWidget.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/VerticalBox.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"

void UMMOStatusWidget::NativeConstruct()
{
    Super::NativeConstruct();
    
    // Find MMO Player Controller
    FindMMOPlayerController();
    
    // Bind button events
    if (ConnectButton)
    {
        ConnectButton->OnClicked.AddDynamic(this, &UMMOStatusWidget::OnConnectButtonClicked);
    }
    
    if (DisconnectButton)
    {
        DisconnectButton->OnClicked.AddDynamic(this, &UMMOStatusWidget::OnDisconnectButtonClicked);
    }
    
    // Initial update
    UpdateServerStatus();
    UpdatePlayerStats();
}

void UMMOStatusWidget::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
    Super::NativeTick(MyGeometry, InDeltaTime);
    
    LastUpdateTime += InDeltaTime;
    
    // Update UI periodically
    if (LastUpdateTime >= UpdateInterval)
    {
        UpdateServerStatus();
        UpdateOnlinePlayersList();
        UpdatePlayerStats();
        LastUpdateTime = 0.0f;
    }
}

void UMMOStatusWidget::UpdateServerStatus()
{
    if (!MMOPlayerController)
    {
        FindMMOPlayerController();
        if (!MMOPlayerController)
        {
            if (ServerStatusText)
            {
                ServerStatusText->SetText(FText::FromString(TEXT("❌ MMO Controller Not Found")));
            }
            return;
        }
    }
    
    // Update server status
    if (ServerStatusText)
    {
        if (MMOPlayerController->IsConnectedToMMO())
        {
            ServerStatusText->SetText(FText::FromString(TEXT("✅ Connected to MMO Server")));
        }
        else
        {
            ServerStatusText->SetText(FText::FromString(TEXT("🔴 Disconnected from MMO Server")));
        }
    }
    
    // Update session ID
    if (SessionIDText && MMOPlayerController->GameServerManager)
    {
        FString SessionID = MMOPlayerController->GameServerManager->SessionID;
        if (!SessionID.IsEmpty())
        {
            SessionIDText->SetText(FText::FromString(FString::Printf(TEXT("Session: %s"), *SessionID.Left(8))));
        }
        else
        {
            SessionIDText->SetText(FText::FromString(TEXT("Session: None")));
        }
    }
    
    // Update button states
    if (ConnectButton && DisconnectButton)
    {
        bool bIsConnected = MMOPlayerController->IsConnectedToMMO();
        ConnectButton->SetIsEnabled(!bIsConnected);
        DisconnectButton->SetIsEnabled(bIsConnected);
    }
}

void UMMOStatusWidget::UpdateOnlinePlayersList()
{
    if (!MMOPlayerController || !OnlinePlayersText)
    {
        return;
    }
    
    int32 PlayerCount = MMOPlayerController->GetOnlinePlayerCount();
    OnlinePlayersText->SetText(FText::FromString(FString::Printf(TEXT("👥 Online Players: %d"), PlayerCount)));
    
    // Optionally update detailed player list in OnlinePlayersBox
    if (OnlinePlayersBox)
    {
        // Clear existing entries
        OnlinePlayersBox->ClearChildren();
        
        // Add each online player
        TArray<FPlayerData> OnlinePlayers = MMOPlayerController->GetOnlinePlayers();
        for (const FPlayerData& Player : OnlinePlayers)
        {
            // Create text block for each player
            UTextBlock* PlayerText = NewObject<UTextBlock>(this);
            if (PlayerText)
            {
                PlayerText->SetText(FText::FromString(FormatPlayerStats(Player)));
                OnlinePlayersBox->AddChild(PlayerText);
            }
        }
    }
}

void UMMOStatusWidget::UpdatePlayerStats()
{
    if (!MMOPlayerController || !PlayerStatsText)
    {
        return;
    }
    
    FString StatsText = FString::Printf(TEXT("❤️ Health: %d | ⭐ Level: %d | 🏆 Score: %d | ✨ XP: %d"),
        MMOPlayerController->PlayerHealth,
        MMOPlayerController->PlayerLevel,
        MMOPlayerController->PlayerScore,
        MMOPlayerController->PlayerExperience);
    
    PlayerStatsText->SetText(FText::FromString(StatsText));
}

void UMMOStatusWidget::OnConnectButtonClicked()
{
    if (MMOPlayerController)
    {
        MMOPlayerController->ConnectToMMOServer();
        UE_LOG(LogTemp, Log, TEXT("🔄 Manual connect to MMO server requested"));
    }
}

void UMMOStatusWidget::OnDisconnectButtonClicked()
{
    if (MMOPlayerController)
    {
        MMOPlayerController->DisconnectFromMMOServer();
        UE_LOG(LogTemp, Log, TEXT("🔌 Manual disconnect from MMO server requested"));
    }
}

void UMMOStatusWidget::FindMMOPlayerController()
{
    if (GetWorld())
    {
        APlayerController* PC = GetWorld()->GetFirstPlayerController();
        MMOPlayerController = Cast<AMMOPlayerController>(PC);
        
        if (MMOPlayerController)
        {
            UE_LOG(LogTemp, Log, TEXT("✅ MMO Status Widget found MMO Player Controller"));
        }
        else
        {
            UE_LOG(LogTemp, Warning, TEXT("⚠️ MMO Status Widget could not find MMO Player Controller"));
        }
    }
}

FString UMMOStatusWidget::FormatPlayerStats(const FPlayerData& PlayerData) const
{
    return FString::Printf(TEXT("🎮 Lv.%d Player (HP: %d, Score: %d)"),
        PlayerData.Level,
        PlayerData.Health,
        PlayerData.Score);
}