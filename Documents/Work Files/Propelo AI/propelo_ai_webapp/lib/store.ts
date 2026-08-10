import { create } from "zustand";
import { persist } from "zustand/middleware";
import { User, Proposal, Client, Snippet } from "@/types";

interface AppState {
  // User
  user: User | null;
  setUser: (user: User | null) => void;

  // Proposals
  proposals: Proposal[];
  currentProposal: Proposal | null;
  setProposals: (proposals: Proposal[]) => void;
  setCurrentProposal: (proposal: Proposal | null) => void;
  addProposal: (proposal: Proposal) => void;
  updateProposal: (id: string, updates: Partial<Proposal>) => void;
  deleteProposal: (id: string) => void;

  // Clients
  clients: Client[];
  setClients: (clients: Client[]) => void;
  addClient: (client: Client) => void;
  updateClient: (id: string, updates: Partial<Client>) => void;
  deleteClient: (id: string) => void;

  // Snippets
  snippets: Snippet[];
  setSnippets: (snippets: Snippet[]) => void;
  addSnippet: (snippet: Snippet) => void;
  updateSnippet: (id: string, updates: Partial<Snippet>) => void;
  deleteSnippet: (id: string) => void;

  // UI State
  sidebarOpen: boolean;
  setSidebarOpen: (open: boolean) => void;
  theme: "light" | "dark" | "system";
  setTheme: (theme: "light" | "dark" | "system") => void;

  // Loading states
  isLoading: boolean;
  setIsLoading: (loading: boolean) => void;

  // Reset
  reset: () => void;
}

const initialState = {
  user: null,
  proposals: [],
  currentProposal: null,
  clients: [],
  snippets: [],
  sidebarOpen: true,
  theme: "system" as const,
  isLoading: false,
};

export const useStore = create<AppState>()(
  persist(
    (set) => ({
      ...initialState,

      // User actions
      setUser: (user) => set({ user }),

      // Proposal actions
      setProposals: (proposals) => set({ proposals }),
      setCurrentProposal: (proposal) => set({ currentProposal: proposal }),
      addProposal: (proposal) =>
        set((state) => ({
          proposals: [proposal, ...state.proposals],
        })),
      updateProposal: (id, updates) =>
        set((state) => ({
          proposals: state.proposals.map((p) =>
            p.id === id ? { ...p, ...updates } : p
          ),
          currentProposal:
            state.currentProposal?.id === id
              ? { ...state.currentProposal, ...updates }
              : state.currentProposal,
        })),
      deleteProposal: (id) =>
        set((state) => ({
          proposals: state.proposals.filter((p) => p.id !== id),
          currentProposal:
            state.currentProposal?.id === id ? null : state.currentProposal,
        })),

      // Client actions
      setClients: (clients) => set({ clients }),
      addClient: (client) =>
        set((state) => ({ clients: [client, ...state.clients] })),
      updateClient: (id, updates) =>
        set((state) => ({
          clients: state.clients.map((c) =>
            c.id === id ? { ...c, ...updates } : c
          ),
        })),
      deleteClient: (id) =>
        set((state) => ({
          clients: state.clients.filter((c) => c.id !== id),
        })),

      // Snippet actions
      setSnippets: (snippets) => set({ snippets }),
      addSnippet: (snippet) =>
        set((state) => ({ snippets: [snippet, ...state.snippets] })),
      updateSnippet: (id, updates) =>
        set((state) => ({
          snippets: state.snippets.map((s) =>
            s.id === id ? { ...s, ...updates } : s
          ),
        })),
      deleteSnippet: (id) =>
        set((state) => ({
          snippets: state.snippets.filter((s) => s.id !== id),
        })),

      // UI actions
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
      setTheme: (theme) => set({ theme }),
      setIsLoading: (loading) => set({ isLoading: loading }),

      // Reset
      reset: () => set(initialState),
    }),
    {
      name: "propelo-storage",
      partialize: (state) => ({
        theme: state.theme,
        sidebarOpen: state.sidebarOpen,
      }),
    }
  )
);

// Selectors
export const useUser = () => useStore((state) => state.user);
export const useProposals = () => useStore((state) => state.proposals);
export const useCurrentProposal = () => useStore((state) => state.currentProposal);
export const useClients = () => useStore((state) => state.clients);
export const useSnippets = () => useStore((state) => state.snippets);
export const useTheme = () => useStore((state) => state.theme);
export const useSidebarOpen = () => useStore((state) => state.sidebarOpen);
export const useIsLoading = () => useStore((state) => state.isLoading);
