import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles.css';

class ErrorBoundary extends React.Component<{ children: React.ReactNode }, { hasError: boolean; error?: any }>{
  constructor(props: any) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: any) {
    return { hasError: true, error };
  }

  componentDidCatch(error: any, info: any) {
    console.error('[Propelo Popup] Uncaught error:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="w-96 h-[500px] bg-white p-4">
          <h2 className="text-red-600 font-bold mb-2">Something went wrong</h2>
          <p className="text-sm text-gray-700 mb-2">Please reload the extension. If this persists, click "Debug: Show Job Data" inside the popup after reload.</p>
        </div>
      );
    }
    return this.props.children as any;
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </React.StrictMode>
);
