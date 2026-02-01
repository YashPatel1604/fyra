import { useState } from 'react';
import { Home } from './components/Home';
import { Timeline } from './components/Timeline';
import { Compare } from './components/Compare';
import { Settings } from './components/Settings';
import { Plus, BarChart3, ArrowLeftRight, SettingsIcon } from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState<'home' | 'timeline' | 'compare' | 'settings'>('home');

  return (
    <div className="min-h-screen bg-black" style={{ fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif' }}>
      {/* Content */}
      <div className="pb-20">
        {activeTab === 'home' && <Home />}
        {activeTab === 'timeline' && <Timeline />}
        {activeTab === 'compare' && <Compare />}
        {activeTab === 'settings' && <Settings />}
      </div>

      {/* iOS Tab Bar */}
      <div className="fixed bottom-0 left-0 right-0 bg-zinc-900/95 backdrop-blur-lg border-t border-zinc-800 safe-area-inset-bottom">
        <div className="flex items-center justify-around px-2 pt-1 pb-6">
          <button
            onClick={() => setActiveTab('home')}
            className={`flex flex-col items-center gap-1 px-6 py-1 transition-colors ${
              activeTab === 'home' ? 'text-lime-400' : 'text-zinc-500'
            }`}
          >
            <Plus className="w-6 h-6" strokeWidth={2} />
            <span className="text-[10px] font-medium">Check-in</span>
          </button>
          
          <button
            onClick={() => setActiveTab('timeline')}
            className={`flex flex-col items-center gap-1 px-6 py-1 transition-colors ${
              activeTab === 'timeline' ? 'text-lime-400' : 'text-zinc-500'
            }`}
          >
            <BarChart3 className="w-6 h-6" strokeWidth={2} />
            <span className="text-[10px] font-medium">Timeline</span>
          </button>
          
          <button
            onClick={() => setActiveTab('compare')}
            className={`flex flex-col items-center gap-1 px-6 py-1 transition-colors ${
              activeTab === 'compare' ? 'text-lime-400' : 'text-zinc-500'
            }`}
          >
            <ArrowLeftRight className="w-6 h-6" strokeWidth={2} />
            <span className="text-[10px] font-medium">Compare</span>
          </button>
          
          <button
            onClick={() => setActiveTab('settings')}
            className={`flex flex-col items-center gap-1 px-6 py-1 transition-colors ${
              activeTab === 'settings' ? 'text-lime-400' : 'text-zinc-500'
            }`}
          >
            <SettingsIcon className="w-6 h-6" strokeWidth={2} />
            <span className="text-[10px] font-medium">Settings</span>
          </button>
        </div>
      </div>
    </div>
  );
}
