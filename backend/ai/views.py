from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .serializers import RiskAnalysisSerializer, ChatMessageSerializer
import requests
import os


class AIViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['post'])
    def analyze_risk(self, request):
        """Analyze risk based on location, time, and context using Qwen AI"""
        serializer = RiskAnalysisSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        location = serializer.validated_data['location']
        time = serializer.validated_data['time']
        weather = serializer.validated_data.get('weather', 'unknown')
        additional_context = serializer.validated_data.get('additional_context', '')
        
        # Build prompt for Qwen AI
        prompt = f"""Analyze the safety risk for a taxi trip with the following details:
- Location: {location}
- Time: {time}
- Weather: {weather}
- Additional context: {additional_context}

Provide a risk assessment on a scale of 1-10 (1 being very safe, 10 being very dangerous),
along with specific safety recommendations and potential hazards to watch out for.
Format your response as JSON with keys: risk_score, risk_level, recommendations, hazards."""
        
        # Call Qwen API (placeholder - needs actual API key configuration)
        qwen_api_key = os.getenv('QWEN_API_KEY', '')
        if not qwen_api_key:
            # Fallback to basic analysis without AI
            risk_score = self._basic_risk_analysis(time, weather)
            return Response({
                'risk_score': risk_score,
                'risk_level': self._get_risk_level(risk_score),
                'recommendations': self._get_basic_recommendations(risk_score),
                'hazards': self._get_basic_hazards(weather),
                'source': 'basic_analysis'
            })
        
        try:
            # Call Qwen API
            response = requests.post(
                'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
                headers={
                    'Authorization': f'Bearer {qwen_api_key}',
                    'Content-Type': 'application/json'
                },
                json={
                    'model': 'qwen-turbo',
                    'messages': [{'role': 'user', 'content': prompt}],
                    'temperature': 0.7
                }
            )
            
            if response.status_code == 200:
                ai_response = response.json()
                content = ai_response['choices'][0]['message']['content']
                return Response({
                    'analysis': content,
                    'source': 'qwen_ai'
                })
            else:
                raise Exception(f"Qwen API error: {response.status_code}")
                
        except Exception as e:
            # Fallback to basic analysis
            risk_score = self._basic_risk_analysis(time, weather)
            return Response({
                'risk_score': risk_score,
                'risk_level': self._get_risk_level(risk_score),
                'recommendations': self._get_basic_recommendations(risk_score),
                'hazards': self._get_basic_hazards(weather),
                'source': 'basic_analysis_fallback',
                'error': str(e)
            })

    @action(detail=False, methods=['post'])
    def chat(self, request):
        """Chat with AI assistant for safety advice and information"""
        serializer = ChatMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        messages = serializer.validated_data['messages']
        
        qwen_api_key = os.getenv('QWEN_API_KEY', '')
        if not qwen_api_key:
            return Response({
                'error': 'Qwen API key not configured',
                'message': 'Please configure QWEN_API_KEY in environment variables'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        
        try:
            response = requests.post(
                'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
                headers={
                    'Authorization': f'Bearer {qwen_api_key}',
                    'Content-Type': 'application/json'
                },
                json={
                    'model': 'qwen-turbo',
                    'messages': messages,
                    'temperature': 0.7
                }
            )
            
            if response.status_code == 200:
                ai_response = response.json()
                content = ai_response['choices'][0]['message']['content']
                return Response({
                    'response': content,
                    'source': 'qwen_ai'
                })
            else:
                return Response({
                    'error': f'Qwen API error: {response.status_code}',
                    'message': response.text
                }, status=status.HTTP_502_BAD_GATEWAY)
                
        except Exception as e:
            return Response({
                'error': str(e),
                'message': 'Failed to connect to Qwen AI service'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

    def _basic_risk_analysis(self, time, weather):
        """Basic risk analysis without AI"""
        risk_score = 3  # Base score
        
        # Time-based risk
        if 'night' in time.lower() or 'evening' in time.lower():
            risk_score += 2
        if 'midnight' in time.lower() or 'late' in time.lower():
            risk_score += 2
            
        # Weather-based risk
        if 'rain' in weather.lower():
            risk_score += 2
        if 'storm' in weather.lower() or 'thunder' in weather.lower():
            risk_score += 3
        if 'fog' in weather.lower():
            risk_score += 2
            
        return min(10, max(1, risk_score))

    def _get_risk_level(self, score):
        if score <= 2:
            return 'Very Low'
        elif score <= 4:
            return 'Low'
        elif score <= 6:
            return 'Medium'
        elif score <= 8:
            return 'High'
        else:
            return 'Very High'

    def _get_basic_recommendations(self, score):
        recommendations = []
        if score >= 5:
            recommendations.append('Share your trip details with someone')
            recommendations.append('Keep your phone charged and accessible')
        if score >= 7:
            recommendations.append('Use the SOS feature if you feel unsafe')
            recommendations.append('Verify the driver and taxi before boarding')
        if score >= 9:
            recommendations.append('Consider postponing your trip if possible')
            recommendations.append('Use trusted taxi services with verified drivers')
        return recommendations

    def _get_basic_hazards(self, weather):
        hazards = []
        if 'rain' in weather.lower():
            hazards.append('Slippery roads')
            hazards.append('Reduced visibility')
        if 'fog' in weather.lower():
            hazards.append('Poor visibility')
            hazards.append('Difficulty identifying landmarks')
        if 'storm' in weather.lower():
            hazards.append('Dangerous road conditions')
            hazards.append('Potential for vehicle breakdown')
        return hazards
