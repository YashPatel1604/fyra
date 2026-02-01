import { useState } from 'react';
import { Camera, TrendingUp, Award, Ruler } from 'lucide-react';

export function Home() {
  const [weight, setWeight] = useState('168');
  const [selectedWins, setSelectedWins] = useState<string[]>([]);
  const [waist, setWaist] = useState('');
  const [chest, setChest] = useState('');
  const [arms, setArms] = useState('');
  const [photos, setPhotos] = useState<{ front: boolean; side: boolean; back: boolean }>({
    front: false,
    side: false,
    back: false
  });

  const nonScaleWins = [
    'Clothes fit better',
    'Veins more visible',
    'More definition',
    'Strength up',
    'Energy improved',
    'Sleep better'
  ];

  const toggleWin = (win: string) => {
    if (selectedWins.includes(win)) {
      setSelectedWins(selectedWins.filter(w => w !== win));
    } else {
      setSelectedWins([...selectedWins, win]);
    }
  };

  const handlePhotoUpload = (type: 'front' | 'side' | 'back') => {
    setPhotos({ ...photos, [type]: true });
  };

  return (
    <div className="min-h-screen bg-black">
      {/* Header */}
      <div className="bg-zinc-900 border-b border-zinc-800 sticky top-0 z-10">
        <div className="px-6 pt-12 pb-6">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <TrendingUp className="w-6 h-6 text-black" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">
                Track Your Progress
              </h1>
              <p className="text-sm text-zinc-400">
                {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="px-6 py-8">
        {/* Weight Card */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-8 mb-6">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 bg-lime-400 rounded-2xl flex items-center justify-center flex-shrink-0 shadow-lg shadow-lime-400/50">
              <TrendingUp className="w-7 h-7 text-black" />
            </div>
            <div className="flex-1">
              <label className="block text-sm font-semibold text-zinc-400 mb-2">
                Today's Weight
              </label>
              <div className="flex items-baseline gap-2">
                <input
                  type="number"
                  value={weight}
                  onChange={(e) => setWeight(e.target.value)}
                  className="text-5xl font-bold bg-transparent border-none outline-none w-32 text-white"
                  step="0.1"
                />
                <span className="text-2xl font-medium text-zinc-500">lbs</span>
              </div>
            </div>
          </div>
        </div>

        {/* Photos Card */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-8 mb-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-14 h-14 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
              <Camera className="w-7 h-7 text-black" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-white">Progress Photos</h2>
              <p className="text-sm text-zinc-400">Capture your transformation</p>
            </div>
          </div>
          
          <div className="grid grid-cols-3 gap-4">
            {(['front', 'side', 'back'] as const).map((type) => (
              <button
                key={type}
                onClick={() => handlePhotoUpload(type)}
                className="group relative aspect-[3/4] bg-zinc-800 rounded-2xl border-2 border-dashed border-zinc-700 hover:border-lime-400 hover:bg-zinc-800/50 transition-all duration-300 overflow-hidden"
              >
                {photos[type] ? (
                  <div className="absolute inset-0 bg-lime-400 flex items-center justify-center shadow-inner">
                    <Camera className="w-8 h-8 text-black" />
                  </div>
                ) : (
                  <div className="absolute inset-0 flex flex-col items-center justify-center gap-2">
                    <Camera className="w-8 h-8 text-zinc-600 group-hover:text-lime-400 transition-colors" />
                    <span className="text-sm font-medium text-zinc-500 group-hover:text-lime-400 transition-colors capitalize">
                      {type}
                    </span>
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>

        <div className="grid gap-6">
          {/* Non-Scale Wins Card */}
          <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-14 h-14 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
                <Award className="w-7 h-7 text-black" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">Non-Scale Wins</h2>
                <p className="text-sm text-zinc-400">Optional</p>
              </div>
            </div>
            
            <div className="flex flex-wrap gap-2">
              {nonScaleWins.map((win) => (
                <button
                  key={win}
                  onClick={() => toggleWin(win)}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                    selectedWins.includes(win)
                      ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                      : 'bg-zinc-800 text-zinc-300 hover:bg-zinc-700 border border-zinc-700'
                  }`}
                >
                  {win}
                </button>
              ))}
            </div>
          </div>

          {/* Measurements Card */}
          <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-14 h-14 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
                <Ruler className="w-7 h-7 text-black" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">Measurements</h2>
                <p className="text-sm text-zinc-400">Optional</p>
              </div>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-semibold text-zinc-400 mb-2">
                  Waist
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    value={waist}
                    onChange={(e) => setWaist(e.target.value)}
                    placeholder="32"
                    className="flex-1 px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl outline-none focus:ring-2 focus:ring-lime-400 focus:border-transparent transition-all text-white placeholder:text-zinc-600"
                    step="0.1"
                  />
                  <span className="text-zinc-500 font-medium">in</span>
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-semibold text-zinc-400 mb-2">
                  Chest
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    value={chest}
                    onChange={(e) => setChest(e.target.value)}
                    placeholder="40"
                    className="flex-1 px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl outline-none focus:ring-2 focus:ring-lime-400 focus:border-transparent transition-all text-white placeholder:text-zinc-600"
                    step="0.1"
                  />
                  <span className="text-zinc-500 font-medium">in</span>
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-semibold text-zinc-400 mb-2">
                  Arms
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    value={arms}
                    onChange={(e) => setArms(e.target.value)}
                    placeholder="14"
                    className="flex-1 px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-xl outline-none focus:ring-2 focus:ring-lime-400 focus:border-transparent transition-all text-white placeholder:text-zinc-600"
                    step="0.1"
                  />
                  <span className="text-zinc-500 font-medium">in</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Save Button */}
        <button className="w-full mt-8 bg-lime-400 hover:bg-lime-300 text-black font-bold py-5 rounded-2xl shadow-2xl shadow-lime-400/50 hover:shadow-lime-400/70 transition-all duration-300 transform hover:scale-[1.02]">
          Save Today's Progress
        </button>
      </div>
    </div>
  );
}
