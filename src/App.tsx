import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { AuthProvider } from './hooks/useAuth'
import { ProtectedRoute } from './components/ProtectedRoute'
import { Login } from './pages/Login'
import { Home } from './pages/Home'
import { Onboarding } from './pages/Onboarding'
import { CircleSettings } from './pages/CircleSettings'
import { Capture } from './pages/Capture'
import { PhotoDetail } from './pages/PhotoDetail'
import { Profile } from './pages/Profile'
import { Party } from './pages/Party'
import { CircleHome } from './pages/CircleHome'

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/profile"
            element={
              <ProtectedRoute>
                <Profile />
              </ProtectedRoute>
            }
          />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Home />
              </ProtectedRoute>
            }
          />
          <Route
            path="/onboarding"
            element={
              <ProtectedRoute>
                <Onboarding />
              </ProtectedRoute>
            }
          />
          <Route
            path="/circles/:id"
            element={
              <ProtectedRoute>
                <CircleHome />
              </ProtectedRoute>
            }
          />
          <Route
            path="/circles/:id/settings"
            element={
              <ProtectedRoute>
                <CircleSettings />
              </ProtectedRoute>
            }
          />
          <Route
            path="/circles/:id/capture"
            element={
              <ProtectedRoute>
                <Capture />
              </ProtectedRoute>
            }
          />
          <Route
            path="/circles/:id/photos/:photoId"
            element={
              <ProtectedRoute>
                <PhotoDetail />
              </ProtectedRoute>
            }
          />
          <Route
            path="/circles/:id/party"
            element={
              <ProtectedRoute>
                <Party />
              </ProtectedRoute>
            }
          />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
