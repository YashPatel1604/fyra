import { useState } from 'react';
import { Calendar, Sparkles, Film, X } from 'lucide-react';

export function Compare() {
  const [selectedPose, setSelectedPose] = useState<'Front' | 'Side' | 'Back'>('Front');
  const [fromDate, setFromDate] = useState<string | null>(null);
  const [toDate, setToDate] = useState<string | null>(null);
  const [showBanner, setShowBanner] = useState(true);
  const [hideWeightChange, setHideWeightChange] = useState(false);

  const poses = ['Front', 'Side', 'Back'] as const;
  const hasBaseline = true;
  const hasWhy = true;
  const whyText = "I want to feel more confident and energetic in my daily life.";

  const presets = [
    { label: 'First vs Latest', from: 'Jan 1, 2025', to: 'Jan 29, 2025' },
    { label: '30 days ago', from: 'Dec 29, 2024', to: 'Jan 29, 2025' },
    { label: 'This month', from: 'Jan 1, 2025', to: 'Jan 31, 2025' },
    { label: 'This week', from: 'Jan 22, 2025', to: 'Jan 29, 2025' },
    { label: 'Best change', from: 'Jan 8, 2025', to: 'Jan 29, 2025' }
  ];

  if (hasBaseline) {
    presets.push({ label: 'Baseline vs Today', from: 'Jan 1, 2025', to: 'Jan 29, 2025' });
  }

  const handlePreset = (preset: { from: string; to: string }) => {
    setFromDate(preset.from);
    setToDate(preset.to);
  };

  const bothSelected = fromDate && toDate;
  const daysBetween = bothSelected ? 28 : 0;
  const weightChange = bothSelected ? -7 : 0;

  return (
    <div className="min-h-screen bg-black">
      {/* Header */}
      <div className="bg-zinc-900 border-b border-zinc-800">
        <div className="px-6 pt-12 pb-6">
          <h1 className="text-4xl font-bold text-white">
            Compare
          </h1>
          <p className="text-sm text-zinc-400 mt-1">See your transformation</p>
        </div>
      </div>

      <div className="px-6 py-6 space-y-5">
        {/* Why You Started Card */}
        {hasWhy && (
          <div className="bg-zinc-900 border border-lime-400/30 rounded-3xl p-6">
            <div className="flex gap-3">
              <div className="text-2xl">💪</div>
              <div>
                <h3 className="font-bold text-lime-400 mb-1">Why You Started</h3>
                <p className="text-zinc-300">{whyText}</p>
              </div>
            </div>
          </div>
        )}

        {/* Compare Nudge Banner */}
        {showBanner && (
          <div className="bg-lime-400 rounded-3xl shadow-2xl shadow-lime-400/30 overflow-hidden">
            <div className="px-6 py-4 flex items-start gap-3">
              <Sparkles className="w-5 h-5 text-black flex-shrink-0 mt-0.5" />
              <p className="flex-1 text-black font-bold">
                Progress shows best over weeks
              </p>
              <button
                onClick={() => setShowBanner(false)}
                className="text-black/60 hover:text-black transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>
        )}

        {/* Quick Compare Presets */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <h3 className="font-bold text-white mb-4">Quick Compare</h3>
          <div className="flex flex-wrap gap-2">
            {presets.map((preset) => (
              <button
                key={preset.label}
                onClick={() => handlePreset(preset)}
                className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-300 hover:text-lime-400 rounded-full text-sm font-medium transition-all"
              >
                {preset.label}
              </button>
            ))}
          </div>
        </div>

        {/* Timelapse Card */}
        <div className="bg-lime-400 rounded-3xl shadow-2xl shadow-lime-400/30 p-6 text-black">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-black/10 rounded-2xl flex items-center justify-center">
              <Film className="w-6 h-6 text-black" />
            </div>
            <div>
              <h3 className="font-bold text-lg">Progress Timelapse</h3>
              <p className="text-sm text-black/70">Animate your transformation</p>
            </div>
          </div>
          <button className="w-full bg-black text-lime-400 font-bold py-3 rounded-2xl hover:bg-zinc-900 transition-all shadow-xl">
            Create Timelapse
          </button>
        </div>

        {/* Pose Selector */}
        <div className="flex gap-2">
          {poses.map((pose) => (
            <button
              key={pose}
              onClick={() => setSelectedPose(pose)}
              className={`flex-1 py-3 rounded-2xl text-sm font-bold transition-all ${
                selectedPose === pose
                  ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                  : 'bg-zinc-900 text-zinc-300 border border-zinc-800 hover:border-zinc-700'
              }`}
            >
              {pose}
            </button>
          ))}
        </div>

        {/* Date Selectors */}
        <div className="grid grid-cols-2 gap-4">
          <button
            className={`bg-zinc-900 rounded-3xl p-5 flex flex-col gap-3 transition-all ${
              fromDate 
                ? 'border-2 border-lime-400 shadow-lg shadow-lime-400/20' 
                : 'border border-zinc-800 hover:border-zinc-700'
            }`}
          >
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 bg-lime-400 rounded-xl flex items-center justify-center shadow-lg shadow-lime-400/50">
                <Calendar className="w-5 h-5 text-black" />
              </div>
              <span className="text-xs font-semibold text-zinc-500 uppercase">From</span>
            </div>
            <span className="text-sm font-bold text-white">
              {fromDate || 'Select date'}
            </span>
          </button>

          <button
            className={`bg-zinc-900 rounded-3xl p-5 flex flex-col gap-3 transition-all ${
              toDate 
                ? 'border-2 border-lime-400 shadow-lg shadow-lime-400/20' 
                : 'border border-zinc-800 hover:border-zinc-700'
            }`}
          >
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 bg-lime-400 rounded-xl flex items-center justify-center shadow-lg shadow-lime-400/50">
                <Calendar className="w-5 h-5 text-black" />
              </div>
              <span className="text-xs font-semibold text-zinc-500 uppercase">To</span>
            </div>
            <span className="text-sm font-bold text-white">
              {toDate || 'Select date'}
            </span>
          </button>
        </div>

        {/* Comparison Content */}
        {bothSelected ? (
          <>
            {/* Stats */}
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-5">
                <p className="text-sm text-zinc-400 mb-1">Days Between</p>
                <p className="text-3xl font-bold text-white">{daysBetween}</p>
              </div>
              {!hideWeightChange && (
                <div className="bg-zinc-900 border border-lime-400/30 rounded-3xl shadow-xl p-5">
                  <p className="text-sm text-lime-400 mb-1">Weight Change</p>
                  <p className="text-3xl font-bold text-lime-400">{weightChange} lbs</p>
                </div>
              )}
            </div>

            {/* Lighting Hint */}
            <div className="text-center">
              <p className="text-xs text-zinc-500">✨ Best results with similar lighting</p>
            </div>

            {/* Side-by-Side Photos */}
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 overflow-hidden">
                <div className="aspect-[3/4] bg-gradient-to-br from-zinc-700 to-zinc-800 flex items-center justify-center">
                  <div className="w-full h-full bg-gradient-to-br from-zinc-700 to-zinc-800" />
                </div>
                <div className="p-4 text-center bg-zinc-900">
                  <p className="text-sm font-bold text-white">{fromDate}</p>
                  <p className="text-xs text-zinc-400">Before</p>
                </div>
              </div>

              <div className="bg-zinc-900 rounded-3xl shadow-xl border border-lime-400/50 overflow-hidden">
                <div className="aspect-[3/4] bg-gradient-to-br from-lime-500 to-lime-600 flex items-center justify-center">
                  <div className="w-full h-full bg-gradient-to-br from-lime-500 to-lime-600" />
                </div>
                <div className="p-4 text-center bg-zinc-900">
                  <p className="text-sm font-bold text-lime-400">{toDate}</p>
                  <p className="text-xs text-lime-400/70">After</p>
                </div>
              </div>
            </div>
          </>
        ) : (
          <div className="bg-zinc-900 rounded-3xl p-12 text-center border border-zinc-800">
            <div className="w-20 h-20 bg-zinc-800 rounded-full mx-auto mb-4 flex items-center justify-center">
              <Calendar className="w-10 h-10 text-zinc-600" />
            </div>
            <p className="font-bold text-white mb-2">Select two check-ins</p>
            <p className="text-sm text-zinc-400">
              Use quick presets or tap the date selectors above
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
