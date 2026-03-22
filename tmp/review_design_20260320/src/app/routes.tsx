import { createBrowserRouter } from 'react-router';
import { AppShell } from './components/AppShell';
import { LiveOperations } from './pages/LiveOperations';
import { AIQueue } from './pages/AIQueue';
import { TacticalMap } from './pages/TacticalMap';
import { Governance } from './pages/Governance';
import { Dispatches } from './pages/Dispatches';
import { Guards } from './pages/Guards';
import { Sites } from './pages/Sites';
import { Clients } from './pages/Clients';
import { Events } from './pages/Events';
import { Ledger } from './pages/Ledger';
import { Reports } from './pages/Reports';
import { Admin } from './pages/Admin';
import LiveOperations_Sovereign from './pages/LiveOperations_Sovereign';
import TacticalMap_Sovereign from './pages/TacticalMap_Sovereign';
import Admin_Sovereign from './pages/Admin_Sovereign';
import Governance_Sovereign from './pages/Governance_Sovereign';
import CommandOverview_Sovereign from './pages/CommandOverview_Sovereign';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <AppShell />,
    children: [
      { index: true, element: <LiveOperations /> },
      { path: 'ai-queue', element: <AIQueue /> },
      { path: 'tactical', element: <TacticalMap /> },
      { path: 'governance', element: <Governance /> },
      { path: 'dispatches', element: <Dispatches /> },
      { path: 'guards', element: <Guards /> },
      { path: 'sites', element: <Sites /> },
      { path: 'clients', element: <Clients /> },
      { path: 'events', element: <Events /> },
      { path: 'ledger', element: <Ledger /> },
      { path: 'reports', element: <Reports /> },
      { path: 'admin', element: <Admin /> },
      // Sovereign Variant Routes
      { path: 'sovereign', element: <CommandOverview_Sovereign /> },
      { path: 'sovereign/live', element: <LiveOperations_Sovereign /> },
      { path: 'sovereign/tactical', element: <TacticalMap_Sovereign /> },
      { path: 'sovereign/admin', element: <Admin_Sovereign /> },
      { path: 'sovereign/governance', element: <Governance_Sovereign /> },
    ],
  },
]);