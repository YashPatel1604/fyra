import { useState } from 'react';
import { Camera, TrendingDown, Calendar, Zap, Target } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, ResponsiveContainer, Dot } from 'recharts';

const mockData = [
  { date: 'Jan 1', weight: 175 },
  { date: 'Jan 8', weight: 173 },
  { date: 'Jan 15', weight: 172 },
  { date: 'Jan 22', weight: 170 },
  { date: 'Jan 29', weight: 168 }
];

const mockCheckins = [
  { id: 1, date: 'Jan 29, 2025', weight: 168, isBaseline: false, hasPhoto: true },
  { id: 2, date: 'Jan 22, 2025', weight: 170, isBaseline: false, hasPhoto: true },
  { id: 3, date: 'Jan 15, 2025', weight: 172, isBaseline: false, hasPhoto: false },
  { id: 4, date: 'Jan 8, 2025', weight: 173, isBaseline: false, hasPhoto: true },
  { id: 5, date: 'Jan 1, 2025', weight: 175, isBaseline: true, hasPhoto: true }
];

export function Timeline() {
  const [selectedRange, setSelectedRange] = useState<'7D' | '30D' | '90D' | '6M' | '1Y' | 'All'>('30D');
  const [showDailyPoints, setShowDailyPoints] = useState(true);
  const hasEnoughData = mockData.length >= 3;

  const ranges = ['7D', '30D', '90D', '6M', '1Y', 'All'] as const;

  return (
    <div className="min-h-screen bg-black">
      {/* Header */}
      <div className="bg-zinc-900 border-b border-zinc-800">
        <div className="px-6 pt-12 pb-6">
          <h1 className="text-4xl font-bold text-white">
            Timeline
          </h1>
          <p className="text-sm text-zinc-400 mt-1">Your journey at a glance</p>
        </div>
      </div>

      <div className="px-6 py-6 space-y-5">
        {/* Weight Trend Card */}
        <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 overflow-hidden">
          <div className="p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-12 h-12 bg-lime-400 rounded-2xl flex items-center justify-center shadow-lg shadow-lime-400/50">
                <TrendingDown className="w-6 h-6 text-black" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-white">Weight Trend</h2>
                <p className="text-xs text-zinc-400">Track your progress</p>
              </div>
            </div>
            
            {/* Range Pills */}
            <div className="flex gap-2 mb-5 overflow-x-auto pb-2 scrollbar-hide">
              {ranges.map((range) => (
                <button
                  key={range}
                  onClick={() => setSelectedRange(range)}
                  className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all ${
                    selectedRange === range
                      ? 'bg-lime-400 text-black shadow-lg shadow-lime-400/30'
                      : 'bg-zinc-800 text-zinc-300 hover:bg-zinc-700 border border-zinc-700'
                  }`}
                >
                  {range}
                </button>
              ))}
            </div>

            {/* Chart */}
            {hasEnoughData ? (
              <>
                <div className="bg-zinc-800 rounded-2xl p-4 mb-4">
                  <ResponsiveContainer width="100%" height={200}>
                    <LineChart data={mockData}>
                      <defs>
                        <linearGradient id="colorWeight" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#a3e635" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#a3e635" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <XAxis 
                        dataKey="date" 
                        tick={{ fontSize: 11, fill: '#71717a' }}
                        axisLine={false}
                        tickLine={false}
                      />
                      <YAxis 
                        tick={{ fontSize: 11, fill: '#71717a' }}
                        axisLine={false}
                        tickLine={false}
                        domain={['dataMin - 2', 'dataMax + 2']}
                      />
                      <Line 
                        type="monotone" 
                        dataKey="weight" 
                        stroke="#a3e635" 
                        strokeWidth={3}
                        dot={showDailyPoints ? { fill: '#a3e635', r: 5, strokeWidth: 2, stroke: '#18181b' } : false}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>

                {/* Toggle */}
                <div className="flex items-center justify-between bg-zinc-800 rounded-2xl px-4 py-3">
                  <span className="text-sm font-medium text-zinc-300">Show data points</span>
                  <button
                    onClick={() => setShowDailyPoints(!showDailyPoints)}
                    className={`relative w-14 h-8 rounded-full transition-all ${
                      showDailyPoints ? 'bg-lime-400' : 'bg-zinc-700'
                    }`}
                  >
                    <div
                      className={`absolute top-1 w-6 h-6 ${showDailyPoints ? 'bg-black' : 'bg-zinc-500'} rounded-full shadow-md transition-transform ${
                        showDailyPoints ? 'translate-x-7' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>

                {/* Trend Caption */}
                <div className="mt-4 text-center">
                  <p className="text-sm text-zinc-400">
                    Trending <span className="font-bold text-lime-400">-1.4 lbs/week</span>
                  </p>
                </div>
              </>
            ) : (
              <div className="flex items-center justify-center h-48 bg-zinc-800 rounded-2xl">
                <p className="text-zinc-500">Not enough data yet</p>
              </div>
            )}
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-5">
            <div className="w-10 h-10 bg-lime-400 rounded-xl flex items-center justify-center mb-3 shadow-lg shadow-lime-400/50">
              <Target className="w-5 h-5 text-black" />
            </div>
            <p className="text-sm text-zinc-400 mb-1">30D Change</p>
            <p className="text-2xl font-bold text-white">-7 lbs</p>
          </div>

          <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-5">
            <div className="w-10 h-10 bg-lime-400 rounded-xl flex items-center justify-center mb-3 shadow-lg shadow-lime-400/50">
              <TrendingDown className="w-5 h-5 text-black" />
            </div>
            <p className="text-sm text-zinc-400 mb-1">Weekly Rate</p>
            <p className="text-2xl font-bold text-white">-1.4 lbs</p>
          </div>

          <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-5">
            <div className="w-10 h-10 bg-lime-400 rounded-xl flex items-center justify-center mb-3 shadow-lg shadow-lime-400/50">
              <Calendar className="w-5 h-5 text-black" />
            </div>
            <p className="text-sm text-zinc-400 mb-1">This Month</p>
            <p className="text-2xl font-bold text-white">5 days</p>
          </div>

          <div className="bg-zinc-900 rounded-3xl shadow-xl border border-zinc-800 p-5">
            <div className="w-10 h-10 bg-lime-400 rounded-xl flex items-center justify-center mb-3 shadow-lg shadow-lime-400/50">
              <Zap className="w-5 h-5 text-black" />
            </div>
            <p className="text-sm text-zinc-400 mb-1">Consistency</p>
            <p className="text-2xl font-bold text-white">71%</p>
          </div>
        </div>

        {/* Insights */}
        <div className="bg-zinc-900 border border-lime-400/30 rounded-3xl p-5">
          <div className="flex gap-3">
            <div className="text-2xl">💡</div>
            <div>
              <p className="font-medium text-white mb-1">Add measurements for deeper insights</p>
              <p className="text-sm text-zinc-400">You're on track with your current pace</p>
            </div>
          </div>
        </div>

        {/* Check-ins */}
        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-zinc-500 uppercase tracking-wide px-1">Recent Check-ins</h3>
          {mockCheckins.length > 0 ? (
            mockCheckins.map((checkin, index) => (
              <button
                key={checkin.id}
                className="w-full bg-zinc-900 rounded-2xl shadow-xl hover:shadow-2xl border border-zinc-800 hover:border-lime-400/50 p-4 flex items-center gap-4 transition-all hover:scale-[1.01]"
              >
                {/* Thumbnail */}
                <div className="relative">
                  <div className={`w-16 h-16 rounded-2xl flex items-center justify-center flex-shrink-0 ${
                    checkin.hasPhoto 
                      ? 'bg-lime-400 shadow-lg shadow-lime-400/50' 
                      : 'bg-zinc-800'
                  }`}>
                    {!checkin.hasPhoto && <Camera className="w-6 h-6 text-zinc-600" />}
                  </div>
                  {checkin.isBaseline && (
                    <div className="absolute -top-1 -right-1 w-6 h-6 bg-lime-400 rounded-full flex items-center justify-center text-xs shadow-lg">
                      ⭐
                    </div>
                  )}
                </div>

                {/* Content */}
                <div className="flex-1 text-left">
                  <p className="font-semibold text-white">{checkin.date}</p>
                  <p className="text-sm text-zinc-400">{checkin.weight} lbs</p>
                </div>

                <div className="w-8 h-8 bg-zinc-800 rounded-full flex items-center justify-center">
                  <span className="text-zinc-500">→</span>
                </div>
              </button>
            ))
          ) : (
            <div className="bg-zinc-900 rounded-3xl p-12 text-center border border-zinc-800">
              <div className="w-16 h-16 bg-zinc-800 rounded-full mx-auto mb-4 flex items-center justify-center">
                <Camera className="w-8 h-8 text-zinc-600" />
              </div>
              <p className="font-semibold text-white mb-1">No check-ins yet</p>
              <p className="text-sm text-zinc-400">Tap + to add your first check-in</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
