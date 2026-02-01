import { useState } from 'react';
import { Download, Palette, Camera, Scale, Target, Calendar, MessageSquare } from 'lucide-react';

export function Settings() {
  const [weightUnit, setWeightUnit] = useState<'LB' | 'KG'>('LB');
  const [theme, setTheme] = useState<'System' | 'Light' | 'Dark'>('System');
  const [photoFirstMode, setPhotoFirstMode] = useState(false);
  const [photoMode, setPhotoMode] = useState<'Single' | 'Three poses'>('Three poses');
  const [defaultPose, setDefaultPose] = useState<'Front' | 'Side' | 'Back'>('Front');
  const [hideWeightChange, setHideWeightChange] = useState(false);
  const [goalType, setGoalType] = useState<'Lose weight' | 'Gain weight' | 'Maintain' | 'Recomp'>('Lose weight');
  const [targetMin, setTargetMin] = useState('165');
  const [targetMax, setTargetMax] = useState('170');
  const [paceMin, setPaceMin] = useState('1.0');
  const [paceMax, setPaceMax] = useState('1.5');
  const [whyStarted, setWhyStarted] = useState('I want to feel more confident and energetic in my daily life.');
  const [activePeriod, setActivePeriod] = useState(true);

  const lastExport = 'Jan 15, 2025';

  return (
    <div className="min-h-screen bg-black">
      {/* Header */}
      <div className="bg-zinc-900 border-b border-zinc-800">
        <div className="px-6 pt-12 pb-6">
          <h1 className="text-4xl font-bold text-white">
            Settings
          </h1>
          <p className="text-sm text-zinc-400 mt-1">Customize your experience</p>
        </div>
      </div>

      <div className="px-6 py-6 space-y-5">
        {/* Storage Info */}
        <div className="bg-zinc-900 border border-lime-400/30 rounded-3xl p-6">
          <div className="flex gap-3">
            <div className="text-2xl">🔒</div>
            <div>
              <h3 className="font-bold text-lime-400 mb-1">Private & Secure</h3>
              <p className="text-sm text-zinc-300">All data is stored locally on your device</p>
            </div>
          </div>
        </div>

        {/* Export */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 overflow-hidden">
          <div className="p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
                <Download className="w-6 h-6 text-black" />
              </div>
              <div>
                <h2 className="font-bold text-white">Export Data</h2>
                <p className="text-xs text-zinc-400">Last export: {lastExport}</p>
              </div>
            </div>
            <div className="space-y-3">
              <button className="w-full bg-lime-400 hover:bg-lime-300 text-black font-semibold py-3 rounded-2xl transition-all shadow-lg shadow-lime-400/30">
                Export Weight CSV
              </button>
              <button className="w-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-white font-semibold py-3 rounded-2xl transition-all">
                Export Compare Image
              </button>
            </div>
          </div>
        </div>

        {/* Weight Unit */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Scale className="w-6 h-6 text-black" />
            </div>
            <h2 className="font-bold text-white">Weight Unit</h2>
          </div>
          <div className="flex gap-3">
            {(['LB', 'KG'] as const).map((unit) => (
              <button
                key={unit}
                onClick={() => setWeightUnit(unit)}
                className={`flex-1 py-3 rounded-2xl font-bold transition-all ${
                  weightUnit === unit
                    ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                    : 'bg-zinc-800 text-zinc-300 border border-zinc-700'
                }`}
              >
                {unit}
              </button>
            ))}
          </div>
        </div>

        {/* Appearance */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Palette className="w-6 h-6 text-black" />
            </div>
            <h2 className="font-bold text-white">Appearance</h2>
          </div>
          <div className="flex gap-3">
            {(['System', 'Light', 'Dark'] as const).map((mode) => (
              <button
                key={mode}
                onClick={() => setTheme(mode)}
                className={`flex-1 py-3 rounded-2xl text-sm font-bold transition-all ${
                  theme === mode
                    ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                    : 'bg-zinc-800 text-zinc-300 border border-zinc-700'
                }`}
              >
                {mode}
              </button>
            ))}
          </div>
        </div>

        {/* Photo Settings */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Camera className="w-6 h-6 text-black" />
            </div>
            <h2 className="font-bold text-white">Photo Settings</h2>
          </div>
          
          {/* Photo-first Mode Toggle */}
          <div className="bg-zinc-800 border border-zinc-700 rounded-2xl p-4 mb-4">
            <div className="flex items-center justify-between mb-2">
              <span className="font-semibold text-white">Photo-first mode</span>
              <button
                onClick={() => setPhotoFirstMode(!photoFirstMode)}
                className={`relative w-14 h-8 rounded-full transition-all ${
                  photoFirstMode ? 'bg-lime-400' : 'bg-zinc-700'
                }`}
              >
                <div
                  className={`absolute top-1 w-6 h-6 ${photoFirstMode ? 'bg-black' : 'bg-zinc-500'} rounded-full shadow-md transition-transform ${
                    photoFirstMode ? 'translate-x-7' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>
            <p className="text-xs text-zinc-400">Show photos in timeline instead of weight</p>
          </div>

          {/* Photo Mode */}
          <div className="mb-4">
            <p className="text-sm font-semibold text-zinc-400 mb-2">Photo mode</p>
            <div className="flex gap-3">
              {(['Single', 'Three poses'] as const).map((mode) => (
                <button
                  key={mode}
                  onClick={() => setPhotoMode(mode)}
                  className={`flex-1 py-2.5 rounded-xl text-sm font-bold transition-all ${
                    photoMode === mode
                      ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                      : 'bg-zinc-800 text-zinc-300 border border-zinc-700'
                  }`}
                >
                  {mode}
                </button>
              ))}
            </div>
          </div>

          {/* Default Pose (if Single mode) */}
          {photoMode === 'Single' && (
            <div>
              <p className="text-sm font-semibold text-zinc-400 mb-2">Default pose</p>
              <div className="flex gap-2">
                {(['Front', 'Side', 'Back'] as const).map((pose) => (
                  <button
                    key={pose}
                    onClick={() => setDefaultPose(pose)}
                    className={`flex-1 py-2.5 rounded-xl text-sm font-bold transition-all ${
                      defaultPose === pose
                        ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                        : 'bg-zinc-800 text-zinc-300 border border-zinc-700'
                    }`}
                  >
                    {pose}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Compare Settings */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Scale className="w-6 h-6 text-black" />
            </div>
            <h2 className="font-bold text-white">Compare Settings</h2>
          </div>
          <div className="bg-zinc-800 border border-zinc-700 rounded-2xl p-4">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-white">Hide weight change</span>
              <button
                onClick={() => setHideWeightChange(!hideWeightChange)}
                className={`relative w-14 h-8 rounded-full transition-all ${
                  hideWeightChange ? 'bg-lime-400' : 'bg-zinc-700'
                }`}
              >
                <div
                  className={`absolute top-1 w-6 h-6 ${hideWeightChange ? 'bg-black' : 'bg-zinc-500'} rounded-full shadow-md transition-transform ${
                    hideWeightChange ? 'translate-x-7' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>
          </div>
        </div>

        {/* Goal */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Target className="w-6 h-6 text-black" />
            </div>
            <h2 className="font-bold text-white">Your Goal</h2>
          </div>

          <div className="space-y-4">
            <div className="bg-zinc-800 border border-zinc-700 rounded-2xl p-4">
              <p className="text-sm font-semibold text-zinc-400 mb-2">Goal type</p>
              <p className="font-bold text-lime-400">{goalType}</p>
            </div>

            {(goalType === 'Lose weight' || goalType === 'Gain weight') && (
              <div className="grid grid-cols-2 gap-3">
                <div className="bg-zinc-800 rounded-2xl p-3">
                  <p className="text-xs text-zinc-400 mb-1">Target Min</p>
                  <input
                    type="number"
                    value={targetMin}
                    onChange={(e) => setTargetMin(e.target.value)}
                    className="w-full text-lg font-bold bg-transparent outline-none text-white"
                  />
                  <p className="text-xs text-zinc-500">lbs</p>
                </div>
                <div className="bg-zinc-800 rounded-2xl p-3">
                  <p className="text-xs text-zinc-400 mb-1">Target Max</p>
                  <input
                    type="number"
                    value={targetMax}
                    onChange={(e) => setTargetMax(e.target.value)}
                    className="w-full text-lg font-bold bg-transparent outline-none text-white"
                  />
                  <p className="text-xs text-zinc-500">lbs</p>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              <div className="bg-zinc-800 rounded-2xl p-3">
                <p className="text-xs text-zinc-400 mb-1">Pace Min</p>
                <input
                  type="number"
                  value={paceMin}
                  onChange={(e) => setPaceMin(e.target.value)}
                  className="w-full text-lg font-bold bg-transparent outline-none text-white"
                  step="0.1"
                />
                <p className="text-xs text-zinc-500">lbs/week</p>
              </div>
              <div className="bg-zinc-800 rounded-2xl p-3">
                <p className="text-xs text-zinc-400 mb-1">Pace Max</p>
                <input
                  type="number"
                  value={paceMax}
                  onChange={(e) => setPaceMax(e.target.value)}
                  className="w-full text-lg font-bold bg-transparent outline-none text-white"
                  step="0.1"
                />
                <p className="text-xs text-zinc-500">lbs/week</p>
              </div>
            </div>
          </div>
        </div>

        {/* Progress Period */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Calendar className="w-6 h-6 text-black" />
            </div>
            <div>
              <h2 className="font-bold text-white">Progress Period</h2>
              <p className="text-xs text-zinc-400">
                {activePeriod ? 'Jan 1, 2025 - Present' : 'No active period'}
              </p>
            </div>
          </div>
          <button className="w-full bg-lime-400 hover:bg-lime-300 text-black font-bold py-3 rounded-2xl transition-all shadow-lg shadow-lime-400/30">
            Start New Period
          </button>
        </div>

        {/* Why You Started */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <MessageSquare className="w-6 h-6 text-black" />
            </div>
            <h2 className="font-bold text-white">Why You Started</h2>
          </div>
          <textarea
            value={whyStarted}
            onChange={(e) => setWhyStarted(e.target.value)}
            className="w-full bg-zinc-800 border border-zinc-700 rounded-2xl p-4 text-white outline-none resize-none focus:border-lime-400 transition-all placeholder:text-zinc-600"
            rows={3}
            placeholder="What's motivating you?"
          />
        </div>
      </div>
    </div>
  );
}
