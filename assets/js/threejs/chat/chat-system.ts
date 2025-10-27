// Chat System with Slash Commands
export interface ChatMessage {
  id: string;
  username: string;
  message: string;
  timestamp: string;
  type: 'system' | 'global' | 'tell' | 'guild' | 'location';
  color?: string;
}

export interface ChatCommand {
  name: string;
  aliases: string[];
  description: string;
  usage: string;
  handler: (args: string[], context: ChatContext) => Promise<void> | void;
}

export interface ChatContext {
  sendMessage: (message: string, type?: string) => void;
  pushEvent: (event: string, payload: any) => void;
  currentUser: { id: string; username: string };
  getPosition: () => { x: number; y: number; z: number };
  warpTo: (x: number, y: number, z: number) => void;
}

export class ChatSystem {
  private commands: Map<string, ChatCommand> = new Map();
  private messageHistory: ChatMessage[] = [];
  private ignoredUsers: Set<string> = new Set();
  private friends: Set<string> = new Set();
  private context: ChatContext;
  
  constructor(context: ChatContext) {
    this.context = context;
    this.registerDefaultCommands();
    console.log('💬 Chat System initialized');
  }

  /**
   * Register all default slash commands
   */
  private registerDefaultCommands(): void {
    // /loc - Show current location
    this.registerCommand({
      name: 'loc',
      aliases: ['location', 'where'],
      description: 'Display your current location',
      usage: '/loc',
      handler: () => {
        const pos = this.context.getPosition();
        this.context.sendMessage(
          `Your location is ${pos.x}, ${pos.y}, ${pos.z}`,
          'location'
        );
      }
    });

    // /warp - Teleport to coordinates (admin/gm only, validated server-side)
    this.registerCommand({
      name: 'warp',
      aliases: ['teleport', 'tp'],
      description: 'Warp to coordinates (requires permission)',
      usage: '/warp <x> <y> <z>',
      handler: (args) => {
        if (args.length < 3) {
          this.context.sendMessage(
            '❌ Usage: /warp <x> <y> <z>',
            'system'
          );
          return;
        }

        const x = parseFloat(args[0]);
        const y = parseFloat(args[1]);
        const z = parseFloat(args[2]);

        if (isNaN(x) || isNaN(y) || isNaN(z)) {
          this.context.sendMessage(
            '❌ Invalid coordinates. Use numbers.',
            'system'
          );
          return;
        }

        // Send to server for validation
        this.context.pushEvent('warp_request', { x, y, z });
      }
    });

    // /tell - Send private message
    this.registerCommand({
      name: 'tell',
      aliases: ['t', 'msg', 'whisper', 'w'],
      description: 'Send a private message to another player',
      usage: '/tell <username> <message>',
      handler: (args) => {
        if (args.length < 2) {
          this.context.sendMessage(
            '❌ Usage: /tell <username> <message>',
            'system'
          );
          return;
        }

        const targetUsername = args[0];
        const message = args.slice(1).join(' ');

        // Check if user is ignored
        if (this.ignoredUsers.has(targetUsername.toLowerCase())) {
          this.context.sendMessage(
            `❌ You are ignoring ${targetUsername}`,
            'system'
          );
          return;
        }

        // Send tell to server
        this.context.pushEvent('send_tell', {
          target: targetUsername,
          message: message
        });

        // Show locally
        this.context.sendMessage(
          `You tell ${targetUsername}: ${message}`,
          'tell'
        );
      }
    });

    // /friend - Add friend
    this.registerCommand({
      name: 'friend',
      aliases: ['addfriend', 'buddy'],
      description: 'Add a player to your friends list',
      usage: '/friend <username>',
      handler: (args) => {
        if (args.length < 1) {
          this.context.sendMessage(
            '❌ Usage: /friend <username>',
            'system'
          );
          return;
        }

        const username = args[0];
        this.friends.add(username.toLowerCase());
        
        // Send to server
        this.context.pushEvent('add_friend', { username });
        
        this.context.sendMessage(
          `✅ Added ${username} to your friends list`,
          'system'
        );
      }
    });

    // /unfriend - Remove friend
    this.registerCommand({
      name: 'unfriend',
      aliases: ['removefriend'],
      description: 'Remove a player from your friends list',
      usage: '/unfriend <username>',
      handler: (args) => {
        if (args.length < 1) {
          this.context.sendMessage(
            '❌ Usage: /unfriend <username>',
            'system'
          );
          return;
        }

        const username = args[0];
        this.friends.delete(username.toLowerCase());
        
        // Send to server
        this.context.pushEvent('remove_friend', { username });
        
        this.context.sendMessage(
          `✅ Removed ${username} from your friends list`,
          'system'
        );
      }
    });

    // /friends - List friends
    this.registerCommand({
      name: 'friends',
      aliases: ['friendlist', 'buddies'],
      description: 'Show your friends list',
      usage: '/friends',
      handler: () => {
        if (this.friends.size === 0) {
          this.context.sendMessage(
            'You have no friends in your list',
            'system'
          );
        } else {
          const friendsList = Array.from(this.friends).join(', ');
          this.context.sendMessage(
            `Friends: ${friendsList}`,
            'system'
          );
        }
      }
    });

    // /ignore - Ignore user
    this.registerCommand({
      name: 'ignore',
      aliases: ['block'],
      description: 'Ignore messages from a player',
      usage: '/ignore <username>',
      handler: (args) => {
        if (args.length < 1) {
          this.context.sendMessage(
            '❌ Usage: /ignore <username>',
            'system'
          );
          return;
        }

        const username = args[0];
        this.ignoredUsers.add(username.toLowerCase());
        
        // Send to server
        this.context.pushEvent('ignore_user', { username });
        
        this.context.sendMessage(
          `✅ You are now ignoring ${username}`,
          'system'
        );
      }
    });

    // /unignore - Unignore user
    this.registerCommand({
      name: 'unignore',
      aliases: ['unblock'],
      description: 'Stop ignoring a player',
      usage: '/unignore <username>',
      handler: (args) => {
        if (args.length < 1) {
          this.context.sendMessage(
            '❌ Usage: /unignore <username>',
            'system'
          );
          return;
        }

        const username = args[0];
        this.ignoredUsers.delete(username.toLowerCase());
        
        // Send to server
        this.context.pushEvent('unignore_user', { username });
        
        this.context.sendMessage(
          `✅ You are no longer ignoring ${username}`,
          'system'
        );
      }
    });

    // /who - List online players
    this.registerCommand({
      name: 'who',
      aliases: ['online', 'players'],
      description: 'Show all online players',
      usage: '/who',
      handler: () => {
        this.context.pushEvent('list_online_players', {});
      }
    });

    // /help - Show commands
    this.registerCommand({
      name: 'help',
      aliases: ['commands', '?'],
      description: 'Show available commands',
      usage: '/help [command]',
      handler: (args) => {
        if (args.length > 0) {
          const cmd = this.commands.get(args[0].toLowerCase());
          if (cmd) {
            this.context.sendMessage(
              `${cmd.usage} - ${cmd.description}`,
              'system'
            );
          } else {
            this.context.sendMessage(
              `❌ Unknown command: ${args[0]}`,
              'system'
            );
          }
        } else {
          const commandList = Array.from(this.commands.values())
            .map(cmd => cmd.name)
            .join(', ');
          this.context.sendMessage(
            `Available commands: ${commandList}`,
            'system'
          );
          this.context.sendMessage(
            'Type /help <command> for details',
            'system'
          );
        }
      }
    });

    // /shout - Zone-wide message
    this.registerCommand({
      name: 'shout',
      aliases: ['yell'],
      description: 'Send a message to everyone in the zone',
      usage: '/shout <message>',
      handler: (args) => {
        if (args.length < 1) {
          this.context.sendMessage(
            '❌ Usage: /shout <message>',
            'system'
          );
          return;
        }

        const message = args.join(' ');
        this.context.pushEvent('shout_message', { message });
      }
    });

    // /emote - Character action
    this.registerCommand({
      name: 'emote',
      aliases: ['em', 'me'],
      description: 'Perform an emote action',
      usage: '/emote <action>',
      handler: (args) => {
        if (args.length < 1) {
          this.context.sendMessage(
            '❌ Usage: /emote <action>',
            'system'
          );
          return;
        }

        const action = args.join(' ');
        this.context.pushEvent('emote_action', { action });
      }
    });
  }

  /**
   * Register a custom command
   */
  registerCommand(command: ChatCommand): void {
    this.commands.set(command.name.toLowerCase(), command);
    command.aliases.forEach(alias => {
      this.commands.set(alias.toLowerCase(), command);
    });
  }

  /**
   * Process chat input (handles both commands and messages)
   */
  async processInput(input: string): Promise<boolean> {
    const trimmed = input.trim();
    if (!trimmed) return false;

    // Check if it's a command
    if (trimmed.startsWith('/')) {
      return this.executeCommand(trimmed);
    }

    // Regular chat message
    this.context.pushEvent('chat_message', { message: trimmed });
    return true;
  }

  /**
   * Execute a slash command
   */
  private async executeCommand(input: string): Promise<boolean> {
    // Parse command and arguments
    const parts = input.slice(1).split(/\s+/);
    const commandName = parts[0].toLowerCase();
    const args = parts.slice(1);

    // Find command
    const command = this.commands.get(commandName);
    if (!command) {
      this.context.sendMessage(
        `❌ Unknown command: /${commandName}. Type /help for available commands.`,
        'system'
      );
      return false;
    }

    // Execute command
    try {
      await command.handler(args, this.context);
      return true;
    } catch (error) {
      console.error(`Error executing command /${commandName}:`, error);
      this.context.sendMessage(
        `❌ Error executing command: ${error}`,
        'system'
      );
      return false;
    }
  }

  /**
   * Handle incoming chat message (check if ignored)
   */
  shouldShowMessage(username: string): boolean {
    return !this.ignoredUsers.has(username.toLowerCase());
  }

  /**
   * Add message to history
   */
  addMessage(message: ChatMessage): void {
    // Check if user is ignored
    if (message.type !== 'system' && !this.shouldShowMessage(message.username)) {
      return;
    }

    this.messageHistory.push(message);
    
    // Keep only last 100 messages
    if (this.messageHistory.length > 100) {
      this.messageHistory.shift();
    }
  }

  /**
   * Get message history
   */
  getHistory(): ChatMessage[] {
    return [...this.messageHistory];
  }

  /**
   * Get ignored users
   */
  getIgnoredUsers(): string[] {
    return Array.from(this.ignoredUsers);
  }

  /**
   * Get friends
   */
  getFriends(): string[] {
    return Array.from(this.friends);
  }
}

export default ChatSystem;
