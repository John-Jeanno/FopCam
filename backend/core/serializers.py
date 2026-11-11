import json

from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.db import models
from django.utils import timezone
from django.utils.text import slugify
from datetime import timedelta
from rest_framework import serializers
from rest_framework.validators import UniqueValidator
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .audio_utils import upload_has_audio_payload
from .models import PROFILE_ROLE_CHANGE_CHOICES, UserProfile, Shop, ShopRating, Product, StockMovement, Category, Order, OrderItem, Message, Notification, Follow, Friend, Post, Like, Comment, Coupon, LoyaltyProgram, Referral, ProducerReview, Favorite, ProductView, Recommendation, Share, JobPosting, JobSeekerPost, JobApplication, Story, StoryView, StoryLike, Group, GroupMember, GroupPost, GroupPostLike, GroupPostComment, GroupEvent, GroupEventAttendee, Reel, ReelLike, ReelComment, ReelView, Reaction, MarketplaceListing, MarketplaceFavorite, Hashtag, Mention, Cart, CartItem


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name')


class UserWithProfileSerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'profile_image')
    
    def get_profile_image(self, obj):
        profile = UserProfile.objects.filter(
            user=obj,
            profile_image__isnull=False,
        ).exclude(profile_image='').order_by(
            '-is_active',
            '-updated_at',
            '-id',
        ).first()
        return profile.profile_image.url if profile and profile.profile_image else None


class UserDirectorySerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()
    role = serializers.SerializerMethodField()
    bio = serializers.SerializerMethodField()
    city = serializers.SerializerMethodField()
    is_online = serializers.SerializerMethodField()
    connection_status = serializers.CharField(read_only=True, allow_null=True)
    friend_request_id = serializers.IntegerField(
        source='connection_request_id',
        read_only=True,
        allow_null=True,
    )
    friend_request_direction = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id',
            'username',
            'first_name',
            'last_name',
            'profile_image',
            'role',
            'bio',
            'city',
            'is_online',
            'connection_status',
            'friend_request_id',
            'friend_request_direction',
        )

    def _profile(self, obj):
        profiles = getattr(obj, 'active_profiles', None)
        if profiles:
            return profiles[0]
        return obj.profiles.order_by('-is_active', '-updated_at', '-id').first()

    def get_profile_image(self, obj):
        profile = self._profile(obj)
        if profile is None or not profile.profile_image:
            profile = obj.profiles.filter(
                profile_image__isnull=False,
            ).exclude(profile_image='').order_by(
                '-is_active',
                '-updated_at',
                '-id',
            ).first()
        return profile.profile_image.url if profile and profile.profile_image else None

    def get_role(self, obj):
        profile = self._profile(obj)
        return profile.role if profile else 'particular'

    def get_bio(self, obj):
        profile = self._profile(obj)
        return profile.bio if profile else None

    def get_city(self, obj):
        profile = self._profile(obj)
        return profile.city if profile else None

    def get_is_online(self, obj):
        profile = self._profile(obj)
        return bool(
            profile
            and profile.last_seen_at
            and profile.last_seen_at >= timezone.now() - timedelta(minutes=5)
        )

    def get_friend_request_direction(self, obj):
        requester_id = getattr(obj, 'connection_requester_id', None)
        request = self.context.get('request')
        if requester_id is None or request is None or not request.user.is_authenticated:
            return None
        return 'outgoing' if requester_id == request.user.pk else 'incoming'


class UserPublicProfileSerializer(UserDirectorySerializer):
    cover_image = serializers.SerializerMethodField()
    phone = serializers.SerializerMethodField()
    experience_and_journey = serializers.SerializerMethodField()
    education_and_training = serializers.SerializerMethodField()
    skills = serializers.SerializerMethodField()
    services = serializers.SerializerMethodField()

    class Meta(UserDirectorySerializer.Meta):
        fields = UserDirectorySerializer.Meta.fields + (
            'cover_image',
            'phone',
            'experience_and_journey',
            'education_and_training',
            'skills',
            'services',
        )

    def _active_profile(self, obj):
        profiles = getattr(obj, 'active_profiles', None)
        if profiles:
            return profiles[0]
        return obj.profiles.order_by('-is_active', '-updated_at', '-id').first()

    def get_experience_and_journey(self, obj):
        profile = self._active_profile(obj)
        return profile.experience_and_journey if profile else []

    def get_education_and_training(self, obj):
        profile = self._active_profile(obj)
        return profile.education_and_training if profile else []

    def get_skills(self, obj):
        profile = self._active_profile(obj)
        return profile.skills if profile else []

    def get_services(self, obj):
        profile = self._active_profile(obj)
        return profile.services if profile else []

    def get_phone(self, obj):
        profiles = getattr(obj, 'active_profiles', None)
        profile = profiles[0] if profiles else obj.profiles.order_by(
            '-is_active',
            '-updated_at',
            '-id',
        ).first()
        if profile is None or profile.phone_visibility != 'public':
            return None
        return profile.phone

    def get_cover_image(self, obj):
        profiles = getattr(obj, 'active_profiles', None)
        profile = profiles[0] if profiles else obj.profiles.order_by(
            '-is_active',
            '-updated_at',
            '-id',
        ).first()
        if profile is None or not profile.cover_image:
            profile = obj.profiles.filter(
                cover_image__isnull=False,
            ).exclude(cover_image='').order_by(
                '-is_active',
                '-updated_at',
                '-id',
            ).first()
        return profile.cover_image.url if profile and profile.cover_image else None


class RegisterSerializer(serializers.Serializer):
    USER_TYPE_TO_ROLE = {
        'buyer': 'particular',
        'particular': 'particular',
        'producer': 'producer',
        'shop_owner': 'boutique',
        'boutique': 'boutique',
        'service_provider': 'prestataire',
        'prestataire': 'prestataire',
        'enterprise': 'enterprise',
        'influencer': 'influencer',
        'community_manager': 'community_lead',
        'community_lead': 'community_lead',
        'driver': 'driver',
    }

    username = serializers.CharField(required=True, validators=[UniqueValidator(queryset=User.objects.all())])
    email = serializers.EmailField(required=True, validators=[UniqueValidator(queryset=User.objects.all())])
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    first_name = serializers.CharField(required=True)
    last_name = serializers.CharField(required=True)
    profile_image = serializers.ImageField(required=False, allow_null=True)
    REGISTRABLE_ROLES = tuple(
        (role, label)
        for role, label in UserProfile.ROLE_CHOICES
        if role != 'admin'
    ) + (
        ('buyer', 'Acheteur'),
        ('shop_owner', 'Boutique'),
        ('service_provider', 'Prestataire'),
        ('community_manager', 'Responsable Communautaire'),
    )
    user_type = serializers.ChoiceField(
        choices=REGISTRABLE_ROLES,
        default='particular',
        write_only=True,
    )
    phone = serializers.CharField(required=True)
    motorcycle_plate = serializers.CharField(required=False, allow_blank=True)
    address = serializers.CharField(required=True)
    city = serializers.CharField(required=True)
    country = serializers.CharField(required=True)
    country_code = serializers.RegexField(
        regex=r'^[A-Za-z]{2}$',
        required=False,
        allow_blank=True,
        max_length=2,
    )
    latitude = serializers.CharField(required=False, allow_blank=True)
    longitude = serializers.CharField(required=False, allow_blank=True)
    preferred_language = serializers.ChoiceField(
        choices=UserProfile.LANGUAGE_CHOICES,
        required=False,
        allow_blank=True,
    )

    def validate(self, attrs):
        user_type = attrs.get('user_type')
        if user_type == 'driver':
            if not attrs.get('motorcycle_plate'):
                raise serializers.ValidationError({'motorcycle_plate': 'Le numéro de matricule de la moto est requis pour un livreur.'})
        return attrs

    def create(self, validated_data):
        
        profile_image = validated_data.pop('profile_image', None)
        user_type = validated_data.pop('user_type', 'particular')
        role = self.USER_TYPE_TO_ROLE.get(user_type, user_type)
        phone = validated_data.pop('phone', '')
        motorcycle_plate = validated_data.pop('motorcycle_plate', '')
        address = validated_data.pop('address', '')
        city = validated_data.pop('city', '')
        country = validated_data.pop('country', '')
        country_code = validated_data.pop('country_code', '')
        latitude = validated_data.pop('latitude', None)
        longitude = validated_data.pop('longitude', None)
        preferred_language = validated_data.pop('preferred_language', '')
        
        # Convert to float if provided
        if latitude:
            try:
                latitude = float(latitude)
            except ValueError:
                latitude = None
        else:
            latitude = None
            
        if longitude:
            try:
                longitude = float(longitude)
            except ValueError:
                longitude = None
        else:
            longitude = None

        password = validated_data.pop('password')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=password,
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
        )

        # create profile with geographic data
        profile = UserProfile.objects.create(
            user=user,
            role=role,
            phone=phone,
            motorcycle_plate=motorcycle_plate,
            address=address,
            city=city,
            country=country,
            country_code=country_code.upper(),
            latitude=latitude,
            longitude=longitude,
            preferred_language=preferred_language,
        )
        if profile_image:
            profile.profile_image = profile_image
            profile.save()

        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        login_value = attrs.get(self.username_field)
        password = attrs.get('password')

        if login_value and password:
            user = User.objects.filter(username__iexact=login_value).first()
            if user is None:
                user = User.objects.filter(email__iexact=login_value).first()
            if user is not None and user.check_password(password):
                attrs[self.username_field] = user.username

        return super().validate(attrs)


class ExperienceItemSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150)
    organization = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    location = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True,
    )
    start_date = serializers.CharField(
        max_length=30,
        required=False,
        allow_blank=True,
    )
    end_date = serializers.CharField(
        max_length=30,
        required=False,
        allow_blank=True,
    )
    description = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
    )


class EducationItemSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150)
    institution = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    start_date = serializers.CharField(
        max_length=30,
        required=False,
        allow_blank=True,
    )
    end_date = serializers.CharField(
        max_length=30,
        required=False,
        allow_blank=True,
    )
    description = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
    )


class ServiceItemSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150)
    description = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
    )
    price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=0,
        required=False,
        allow_null=True,
    )
    currency = serializers.CharField(
        max_length=8,
        required=False,
        allow_blank=True,
        default='FCFA',
    )


class SkillItemSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150)
    level = serializers.CharField(
        max_length=60,
        required=False,
        allow_blank=True,
    )
    description = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
    )


class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    role = serializers.CharField(read_only=True)
    phone = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    profile_image = serializers.ImageField(required=False, allow_null=True)
    cover_image = serializers.ImageField(required=False, allow_null=True)
    shop_id = serializers.SerializerMethodField()
    shop_name = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    review_count = serializers.SerializerMethodField()
    first_name = serializers.CharField(write_only=True, required=False)
    last_name = serializers.CharField(write_only=True, required=False)
    country_code = serializers.RegexField(
        regex=r'^[A-Za-z]{2}$',
        required=False,
        allow_blank=True,
    )
    preferred_language = serializers.ChoiceField(
        choices=UserProfile.LANGUAGE_CHOICES,
        required=False,
        allow_blank=True,
    )
    notification_sounds = serializers.JSONField(required=False)
    experience_and_journey = ExperienceItemSerializer(
        many=True,
        required=False,
        max_length=50,
    )
    education_and_training = EducationItemSerializer(
        many=True,
        required=False,
        max_length=50,
    )
    skills = SkillItemSerializer(many=True, required=False, max_length=50)
    services = ServiceItemSerializer(many=True, required=False, max_length=50)

    class Meta:
        model = UserProfile
        fields = ('id', 'user', 'role', 'phone', 'phone_visibility', 'profile_visibility', 'motorcycle_plate', 'address', 'city', 'country', 'country_code', 'preferred_language', 'notification_sounds', 'experience_and_journey', 'education_and_training', 'skills', 'services', 'verified', 'profile_image', 'cover_image', 'bio', 'website', 'shop_id', 'shop_name', 'average_rating', 'review_count', 'first_name', 'last_name')

    def validate_notification_sounds(self, value):
        sound_categories = {'messages', 'games', 'social', 'orders', 'other'}
        sound_choices = {'system', 'soft', 'alert', 'festive'}
        if not isinstance(value, dict):
            raise serializers.ValidationError('Les sonneries doivent être un objet.')
        if set(value) - sound_categories:
            raise serializers.ValidationError('Catégorie de notification inconnue.')
        if any(sound not in sound_choices for sound in value.values()):
            raise serializers.ValidationError('Sonnerie de notification inconnue.')
        return value

    def validate_services(self, services):
        return [
            {
                **service,
                'price': str(service['price'])
                if service.get('price') is not None else None,
            }
            for service in services
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        is_owner = (
            request is not None
            and request.user.is_authenticated
            and request.user.pk == instance.user_id
        )
        if instance.phone_visibility != 'public' and not is_owner:
            data['phone'] = None
        if not is_owner:
            data.pop('notification_sounds', None)
        return data

    def update(self, instance, validated_data):
        # Handle user fields
        first_name = validated_data.pop('first_name', None)
        last_name = validated_data.pop('last_name', None)

        if first_name is not None:
            instance.user.first_name = first_name
        if last_name is not None:
            instance.user.last_name = last_name
        instance.user.save()

        # Handle profile fields
        return super().update(instance, validated_data)

    def get_average_rating(self, obj):
        from django.db.models import Avg
        avg = obj.user.producer_reviews.aggregate(average=Avg('rating'))['average']
        return round(avg, 1) if avg else None

    def get_review_count(self, obj):
        return obj.user.producer_reviews.count()

    def get_shop_id(self, obj):
        shop = obj.user.shops.first()
        return shop.id if shop else None

    def get_shop_name(self, obj):
        shop = obj.user.shops.first()
        return shop.name if shop else None


class CategorySerializer(serializers.ModelSerializer):
    translated_name = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = ('id', 'name', 'slug', 'translated_name', 'category_type')

    def get_translated_name(self, obj):
        # Dictionnaire de traductions des catégories
        translations = {
            'Poultry Farming': {'fr': 'Agriculture', 'en': 'Poultry Farming', 'es': 'Avicultura'},
            'Dairy Farming': {'fr': 'Agriculture', 'en': 'Dairy Farming', 'es': 'Ganadería lechera'},
            'Crop Cultivation': {'fr': 'Culture de plantes', 'en': 'Crop Cultivation', 'es': 'Cultivo de plantas'},
            'Livestock': {'fr': 'Agriculture', 'en': 'Livestock', 'es': 'Ganadería'},
            'Agricultural Equipment': {'fr': 'Équipement agricole', 'en': 'Agricultural Equipment', 'es': 'Equipo agrícola'},
            'Seeds and Fertilizers': {'fr': 'Semences et engrais', 'en': 'Seeds and Fertilizers', 'es': 'Semillas y fertilizantes'},
            'Organic Farming': {'fr': 'Agriculture biologique', 'en': 'Organic Farming', 'es': 'Agricultura orgánica'},
            'Aquaculture': {'fr': 'Aquaculture', 'en': 'Aquaculture', 'es': 'Acuicultura'},
            'Software Development': {'fr': 'Développement logiciel', 'en': 'Software Development', 'es': 'Desarrollo de software'},
            'Hardware': {'fr': 'Matériel informatique', 'en': 'Hardware', 'es': 'Hardware'},
            'Artificial Intelligence': {'fr': 'Intelligence artificielle', 'en': 'Artificial Intelligence', 'es': 'Inteligencia artificial'},
            'Cybersecurity': {'fr': 'Cybersécurité', 'en': 'Cybersecurity', 'es': 'Ciberseguridad'},
            'Cloud Computing': {'fr': 'Informatique en nuage', 'en': 'Cloud Computing', 'es': 'Computación en la nube'},
            'Mobile Apps': {'fr': 'Applications mobiles', 'en': 'Mobile Apps', 'es': 'Aplicaciones móviles'},
            'Web Development': {'fr': 'Développement web', 'en': 'Web Development', 'es': 'Desarrollo web'},
            'Data Science': {'fr': 'Science des données', 'en': 'Data Science', 'es': 'Ciencia de datos'},
            'Hospitals': {'fr': 'Hôpitaux', 'en': 'Hospitals', 'es': 'Hospitales'},
            'Clinics': {'fr': 'Cliniques', 'en': 'Clinics', 'es': 'Clínicas'},
            'Pharmaceuticals': {'fr': 'Pharmacie', 'en': 'Pharmaceuticals', 'es': 'Productos farmacéuticos'},
            'Medical Equipment': {'fr': 'Matériel médical', 'en': 'Medical Equipment', 'es': 'Equipos médicos'},
            'Mental Health': {'fr': 'Santé mentale', 'en': 'Mental Health', 'es': 'Salud mental'},
            'Dental Care': {'fr': 'Soins dentaires', 'en': 'Dental Care', 'es': 'Cuidados dentales'},
            'Nutrition': {'fr': 'Nutrition', 'en': 'Nutrition', 'es': 'Nutrición'},
            'Fitness': {'fr': 'Fitness', 'en': 'Fitness', 'es': 'Fitness'},
            'Schools': {'fr': 'Écoles', 'en': 'Schools', 'es': 'Escuelas'},
            'Universities': {'fr': 'Universités', 'en': 'Universities', 'es': 'Universidades'},
            'Online Learning': {'fr': 'Apprentissage en ligne', 'en': 'Online Learning', 'es': 'Aprendizaje en línea'},
            'Tutoring': {'fr': 'Cours particuliers', 'en': 'Tutoring', 'es': 'Tutoría'},
            'Educational Materials': {'fr': 'Matériel pédagogique', 'en': 'Educational Materials', 'es': 'Materiales educativos'},
            'Language Learning': {'fr': 'Apprentissage des langues', 'en': 'Language Learning', 'es': 'Aprendizaje de idiomas'},
            'Vocational Training': {'fr': 'Formation professionnelle', 'en': 'Vocational Training', 'es': 'Formación profesional'},
            'Government Services': {'fr': 'Services gouvernementaux', 'en': 'Government Services', 'es': 'Servicios gubernamentales'},
            'Public Administration': {'fr': 'Administration publique', 'en': 'Public Administration', 'es': 'Administración pública'},
            'Law Enforcement': {'fr': 'Forces de l’ordre', 'en': 'Law Enforcement', 'es': 'Fuerzas del orden'},
            'Public Health': {'fr': 'Santé publique', 'en': 'Public Health', 'es': 'Salud pública'},
            'Transportation': {'fr': 'Transport', 'en': 'Transportation', 'es': 'Transporte'},
            'Environmental Services': {'fr': 'Services environnementaux', 'en': 'Environmental Services', 'es': 'Servicios ambientales'},
            'Social Services': {'fr': 'Services sociaux', 'en': 'Social Services', 'es': 'Servicios sociales'},
            'Retail Stores': {'fr': 'Magasins de détail', 'en': 'Retail Stores', 'es': 'Tiendas minoristas'},
            'E-commerce': {'fr': 'E-commerce', 'en': 'E-commerce', 'es': 'Comercio electrónico'},
            'Supermarkets': {'fr': 'Supermarchés', 'en': 'Supermarkets', 'es': 'Supermercados'},
            'Fashion': {'fr': 'Mode', 'en': 'Fashion', 'es': 'Moda'},
            'Electronics': {'fr': 'Électronique', 'en': 'Electronics', 'es': 'Electrónica'},
            'Home Goods': {'fr': 'Articles pour la maison', 'en': 'Home Goods', 'es': 'Artículos para el hogar'},
            'Books': {'fr': 'Livres', 'en': 'Books', 'es': 'Libros'},
            'Manufacturing': {'fr': 'Fabrication', 'en': 'Manufacturing', 'es': 'Manufactura'},
            'Automotive': {'fr': 'Automobile', 'en': 'Automotive', 'es': 'Automotriz'},
            'Textiles': {'fr': 'Textiles', 'en': 'Textiles', 'es': 'Textiles'},
            'Chemicals': {'fr': 'Produits chimiques', 'en': 'Chemicals', 'es': 'Productos químicos'},
            'Machinery': {'fr': 'Machinerie', 'en': 'Machinery', 'es': 'Maquinaria'},
            'Food Processing': {'fr': 'Transformation alimentaire', 'en': 'Food Processing', 'es': 'Procesamiento de alimentos'},
            'Banking': {'fr': 'Banque', 'en': 'Banking', 'es': 'Banca'},
            'Insurance': {'fr': 'Assurance', 'en': 'Insurance', 'es': 'Seguros'},
            'Investment': {'fr': 'Investissement', 'en': 'Investment', 'es': 'Inversión'},
            'Accounting': {'fr': 'Comptabilité', 'en': 'Accounting', 'es': 'Contabilidad'},
            'Real Estate': {'fr': 'Immobilier', 'en': 'Real Estate', 'es': 'Bienes raíces'},
            'Mortgages': {'fr': 'Prêts hypothécaires', 'en': 'Mortgages', 'es': 'Hipotecas'},
            'Real Estate Sales': {'fr': 'Ventes immobilières', 'en': 'Real Estate Sales', 'es': 'Ventas inmobiliarias'},
            'Property Management': {'fr': 'Gestion immobilière', 'en': 'Property Management', 'es': 'Administración de propiedades'},
            'Real Estate Development': {'fr': 'Développement immobilier', 'en': 'Real Estate Development', 'es': 'Desarrollo inmobiliario'},
            'Commercial Real Estate': {'fr': 'Immobilier commercial', 'en': 'Commercial Real Estate', 'es': 'Bienes raíces comerciales'},
            'Residential Real Estate': {'fr': 'Immobilier résidentiel', 'en': 'Residential Real Estate', 'es': 'Bienes raíces residenciales'},
            'Transportation Services': {'fr': 'Services de transport', 'en': 'Transportation Services', 'es': 'Servicios de transporte'},
            'Logistics': {'fr': 'Logistique', 'en': 'Logistics', 'es': 'Logística'},
            'Shipping': {'fr': 'Expédition', 'en': 'Shipping', 'es': 'Envío'},
            'Airlines': {'fr': 'Compagnies aériennes', 'en': 'Airlines', 'es': 'Líneas aéreas'},
            'Railways': {'fr': 'Chemins de fer', 'en': 'Railways', 'es': 'Ferrocarriles'},
            'Hotels': {'fr': 'Hôtels', 'en': 'Hotels', 'es': 'Hoteles'},
            'Restaurants': {'fr': 'Restaurants', 'en': 'Restaurants', 'es': 'Restaurantes'},
            'Tourism': {'fr': 'Tourisme', 'en': 'Tourism', 'es': 'Turismo'},
            'Event Planning': {'fr': 'Organisation d’événements', 'en': 'Event Planning', 'es': 'Organización de eventos'},
            'Catering': {'fr': 'Traiteur', 'en': 'Catering', 'es': 'Catering'},
            'Entertainment': {'fr': 'Divertissement', 'en': 'Entertainment', 'es': 'Entretenimiento'},
            'Media': {'fr': 'Média', 'en': 'Media', 'es': 'Medios'},
            'Gaming': {'fr': 'Jeux', 'en': 'Gaming', 'es': 'Juegos'},
            'Music': {'fr': 'Musique', 'en': 'Music', 'es': 'Música'},
            'Film': {'fr': 'Cinéma', 'en': 'Film', 'es': 'Cine'},
            'Sports': {'fr': 'Sports', 'en': 'Sports', 'es': 'Deportes'},
            'Consulting': {'fr': 'Conseil', 'en': 'Consulting', 'es': 'Consultoría'},
            'Legal Services': {'fr': 'Services juridiques', 'en': 'Legal Services', 'es': 'Servicios legales'},
            'Marketing': {'fr': 'Marketing', 'en': 'Marketing', 'es': 'Marketing'},
            'Cleaning Services': {'fr': 'Services de nettoyage', 'en': 'Cleaning Services', 'es': 'Servicios de limpieza'},
            'Maintenance': {'fr': 'Entretien', 'en': 'Maintenance', 'es': 'Mantenimiento'},
            'IT Support': {'fr': 'Support informatique', 'en': 'IT Support', 'es': 'Soporte informático'},
            'Construction': {'fr': 'Construction', 'en': 'Construction', 'es': 'Construcción'},
            'Plumbing': {'fr': 'Plomberie', 'en': 'Plumbing', 'es': 'Fontanería'},
            'Electrical': {'fr': 'Électricité', 'en': 'Electrical', 'es': 'Electricidad'},
            'Landscaping': {'fr': 'Aménagement paysager', 'en': 'Landscaping', 'es': 'Jardinería'},
            'Pet Care': {'fr': 'Soins pour animaux', 'en': 'Pet Care', 'es': 'Cuidado de mascotas'},
            'Beauty Services': {'fr': 'Services de beauté', 'en': 'Beauty Services', 'es': 'Servicios de belleza'},
            'Automotive Services': {'fr': 'Services automobiles', 'en': 'Automotive Services', 'es': 'Servicios automotrices'},
            'Job Postings': {'fr': 'Offres d’emploi', 'en': 'Job Postings', 'es': 'Ofertas de empleo'},
            'Government Information': {'fr': 'Informations gouvernementales', 'en': 'Government Information', 'es': 'Información gubernamental'},
            'Educational Resources': {'fr': 'Ressources éducatives', 'en': 'Educational Resources', 'es': 'Recursos educativos'},
            'Health Information': {'fr': 'Informations santé', 'en': 'Health Information', 'es': 'Información de salud'},
            'Community Events': {'fr': 'Événements communautaires', 'en': 'Community Events', 'es': 'Eventos comunitarios'},
            'Announcements': {'fr': 'Annonces', 'en': 'Announcements', 'es': 'Anuncios'},
            'Classifieds': {'fr': 'Petites annonces', 'en': 'Classifieds', 'es': 'Clasificados'},
            'Lost and Found': {'fr': 'Objets trouvés', 'en': 'Lost and Found', 'es': 'Objetos perdidos'},
            'Volunteering': {'fr': 'Bénévolat', 'en': 'Volunteering', 'es': 'Voluntariado'},
            'Non-Profit': {'fr': 'Organisation à but non lucratif', 'en': 'Non-Profit', 'es': 'Sin fines de lucro'},
            'Charity': {'fr': 'Charité', 'en': 'Charity', 'es': 'Caridad'},
            'Religious Services': {'fr': 'Services religieux', 'en': 'Religious Services', 'es': 'Servicios religiosos'},
            'Arts and Culture': {'fr': 'Arts et culture', 'en': 'Arts and Culture', 'es': 'Artes y cultura'},
            'Science and Research': {'fr': 'Science et recherche', 'en': 'Science and Research', 'es': 'Ciencia e investigación'},
            'Miscellaneous': {'fr': 'Divers', 'en': 'Miscellaneous', 'es': 'Misceláneo'}
        }

        request = self.context.get('request')
        language = 'fr'
        if request:
            language = getattr(request, 'LANGUAGE_CODE', 'fr') or 'fr'
        language = language.split('-')[0]

        category_translations = translations.get(obj.name, {})
        return category_translations.get(language, obj.name)


class ProductSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        source='category',
        write_only=True,
        required=False,
        error_messages={'required': 'La catégorie est requise.'}
    )
    category_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    shop = serializers.SerializerMethodField()
    shop_id = serializers.PrimaryKeyRelatedField(queryset=Shop.objects.all(), source='shop', write_only=True)
    image = serializers.ImageField(required=False, allow_null=True)
    images = serializers.SerializerMethodField()
    video = serializers.FileField(required=False, allow_null=True)
    favorite_count = serializers.SerializerMethodField()
    is_favorited = serializers.SerializerMethodField()
    current_price = serializers.ReadOnlyField()
    is_on_promotion = serializers.ReadOnlyField()
    discount_percentage = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = ('id', 'shop', 'shop_id', 'category', 'category_id', 'category_name', 'title', 'description', 'price', 'promo_price', 'current_price', 'is_on_promotion', 'discount_percentage', 'color_options', 'size_options', 'quantity', 'image', 'images', 'video', 'is_active', 'favorite_count', 'is_favorited')

    def validate(self, attrs):
        for field in ('color_options', 'size_options'):
            options = attrs.get(field, getattr(self.instance, field, []) if self.instance else [])
            if not isinstance(options, list) or any(
                not isinstance(option, str) or not option.strip() or len(option.strip()) > 80
                for option in options
            ):
                raise serializers.ValidationError(
                    {field: 'Saisissez une liste de valeurs textuelles de 80 caractères maximum.'}
                )
            normalized = list(dict.fromkeys(option.strip() for option in options))
            if len(normalized) > 30:
                raise serializers.ValidationError(
                    {field: 'Vous pouvez renseigner au maximum 30 options.'}
                )
            if field in attrs:
                attrs[field] = normalized

        price = attrs.get('price', self.instance.price if self.instance else None)
        promo_price = attrs.get(
            'promo_price',
            self.instance.promo_price if self.instance else None,
        )
        if promo_price is not None and (
            price is None or promo_price <= 0 or promo_price >= price
        ):
            raise serializers.ValidationError(
                {'promo_price': 'Le prix promotionnel doit être positif et inférieur au prix de vente.'}
            )

        category = attrs.get('category')
        category_name = attrs.pop('category_name', '').strip() if 'category_name' in attrs else ''

        if not category and not category_name:
            # For PATCH requests, keep the existing category if already set on the instance.
            if self.instance and getattr(self.instance, 'category', None):
                return attrs
            raise serializers.ValidationError({'category_id': 'La catégorie est requise.'})

        if not category and category_name:
            slug_base = slugify(category_name)[:90] or 'categorie'
            slug = slug_base
            counter = 1
            while Category.objects.filter(slug=slug).exists():
                slug = f"{slug_base}-{counter}"
                counter += 1
            category = Category.objects.create(
                name=category_name,
                slug=slug,
                category_type='product'
            )
            attrs['category'] = category

        return attrs

    def get_favorite_count(self, obj):
        return obj.favorited_by.count()

    def get_discount_percentage(self, obj):
        if not obj.is_on_promotion:
            return 0
        return round((obj.price - obj.current_price) * 100 / obj.price)

    def get_is_favorited(self, obj):
        request = self.context.get('request') if self.context else None
        if request and request.user.is_authenticated:
            return obj.favorited_by.filter(user=request.user).exists()
        return False

    def get_images(self, obj):
        return [image.image.url for image in obj.images.all()]

    def get_shop(self, obj):
        return ShopSerializer(obj.shop, context=self.context).data


class SellerProductSerializer(ProductSerializer):
    purchase_price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=0,
        required=False,
        allow_null=True,
    )

    class Meta(ProductSerializer.Meta):
        fields = ProductSerializer.Meta.fields + ('purchase_price',)


class ShopPhoneNumbersField(serializers.ListField):
    def get_value(self, dictionary):
        value = dictionary.get(self.field_name)
        if isinstance(value, str):
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return value
        return super().get_value(dictionary)


class ShopSerializer(serializers.ModelSerializer):
    owner = UserSerializer(read_only=True)
    logo = serializers.ImageField(required=False, allow_null=True)
    banner = serializers.ImageField(required=False, allow_null=True)
    phone_numbers = ShopPhoneNumbersField(
        child=serializers.CharField(max_length=30, allow_blank=False),
        required=False,
        allow_empty=True,
        max_length=5,
    )
    background_color = serializers.RegexField(r'^#[0-9A-Fa-f]{6}$', required=False)
    text_color = serializers.RegexField(r'^#[0-9A-Fa-f]{6}$', required=False)
    accent_color = serializers.RegexField(r'^#[0-9A-Fa-f]{6}$', required=False)
    font_size = serializers.IntegerField(min_value=12, max_value=24, required=False)
    like_count = serializers.SerializerMethodField()
    vote_count = serializers.SerializerMethodField()
    share_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    is_voted = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    rating_count = serializers.SerializerMethodField()
    user_rating = serializers.SerializerMethodField()

    class Meta:
        model = Shop
        fields = ('id', 'owner', 'name', 'slug', 'description', 'location', 'latitude', 'longitude', 'phone', 'phone_numbers', 'email', 'website', 'logo', 'banner', 'background_color', 'text_color', 'accent_color', 'font_size', 'active', 'delivery_zones', 'opening_hours', 'like_count', 'vote_count', 'share_count', 'is_liked', 'is_voted', 'average_rating', 'rating_count', 'user_rating')

    def validate_phone_numbers(self, value):
        return [number.strip() for number in value if number.strip()]

    def validate(self, attrs):
        if 'phone_numbers' in attrs and 'phone' not in attrs:
            attrs['phone'] = attrs['phone_numbers'][0] if attrs['phone_numbers'] else ''
        return super().validate(attrs)

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_vote_count(self, obj):
        return obj.votes.count()

    def get_share_count(self, obj):
        return obj.shares.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        return bool(
            request
            and request.user.is_authenticated
            and obj.likes.filter(user=request.user).exists()
        )

    def get_is_voted(self, obj):
        request = self.context.get('request')
        return bool(
            request
            and request.user.is_authenticated
            and obj.votes.filter(user=request.user).exists()
        )

    def get_average_rating(self, obj):
        average = obj.ratings.aggregate(average=models.Avg('rating'))['average']
        return round(float(average), 1) if average is not None else 0.0

    def get_rating_count(self, obj):
        return obj.ratings.count()

    def get_user_rating(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return None
        rating = obj.ratings.filter(user=request.user).values_list(
            'rating',
            flat=True,
        ).first()
        return rating

class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = ('product', 'quantity', 'selected_color', 'selected_size', 'price')


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True)

    class Meta:
        model = Order
        fields = ('id', 'buyer', 'status', 'total', 'items')


class MessageSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    recipient = UserWithProfileSerializer(read_only=True)
    reply_to = serializers.SerializerMethodField()
    reply_to_id = serializers.IntegerField(
        required=False,
        allow_null=True,
        write_only=True,
    )
    audio_file = serializers.FileField(required=False, allow_null=True)
    attachment_file = serializers.FileField(required=False, allow_null=True)
    attachment_type = serializers.CharField(required=False, allow_null=True)
    attachment_name = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ('id', 'room', 'user', 'recipient', 'content', 'message_type', 'audio_file', 'audio_duration', 'attachment_file', 'attachment_type', 'attachment_name', 'reply_to', 'reply_to_id', 'is_read', 'created_at')
        read_only_fields = ('id', 'created_at')

    def validate(self, attrs):
        attrs = super().validate(attrs)
        message_type = attrs.get(
            'message_type',
            getattr(self.instance, 'message_type', None),
        )
        audio_upload = attrs.get('attachment_file') or attrs.get('audio_file')
        audio_content_type = (
            getattr(audio_upload, 'content_type', '') if audio_upload else ''
        )
        if message_type == 'audio' or (
            not message_type and audio_content_type.startswith('audio/')
        ):
            if audio_upload and not upload_has_audio_payload(audio_upload):
                raise serializers.ValidationError({
                    'attachment_file': (
                        'Le fichier vocal ne contient pas de son lisible. '
                        'Vérifiez le microphone et réessayez.'
                    ),
                })

        reply_to_id = attrs.pop('reply_to_id', None)
        room = attrs.get('room', getattr(self.instance, 'room', None))
        if reply_to_id is not None:
            try:
                attrs['reply_to'] = Message.objects.get(
                    pk=reply_to_id,
                    room=room,
                )
            except Message.DoesNotExist as error:
                raise serializers.ValidationError({
                    'reply_to_id': (
                        'Le message cité doit appartenir à cette discussion.'
                    ),
                }) from error
        elif 'reply_to_id' in self.initial_data:
            attrs['reply_to'] = None
        return attrs

    def get_reply_to(self, obj):
        message = obj.reply_to
        if message is None:
            return None
        return {
            'id': message.id,
            'content': message.content,
            'message_type': message.message_type,
            'user': {
                'id': message.user_id,
                'username': message.user.username,
            },
        }

    def get_attachment_name(self, obj):
        if obj.attachment_file:
            return obj.attachment_file.name.split('/')[-1]
        return None


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ('id', 'title', 'message', 'type', 'is_read', 'data', 'created_at')


class StockMovementSerializer(serializers.ModelSerializer):
    product_title = serializers.CharField(source='product.title', read_only=True)
    movement_type_display = serializers.CharField(
        source='get_movement_type_display',
        read_only=True,
    )
    order_id = serializers.IntegerField(source='order_item.order_id', read_only=True)

    class Meta:
        model = StockMovement
        fields = (
            'id',
            'product',
            'product_title',
            'movement_type',
            'movement_type_display',
            'quantity_change',
            'unit_cost',
            'note',
            'order_id',
            'created_at',
        )


# Sérialiseurs pour le réseau social
class FollowSerializer(serializers.ModelSerializer):
    follower = UserWithProfileSerializer(read_only=True)
    followed = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = Follow
        fields = ('id', 'follower', 'followed', 'created_at')


class FriendSerializer(serializers.ModelSerializer):
    requester = UserWithProfileSerializer(read_only=True)
    receiver = UserWithProfileSerializer(read_only=True)
    receiver_id = serializers.PrimaryKeyRelatedField(write_only=True, queryset=User.objects.all(), source='receiver')

    class Meta:
        model = Friend
        fields = ('id', 'requester', 'receiver', 'receiver_id', 'status', 'created_at')
        validators = []


class FavoriteSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    product = ProductSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(write_only=True, queryset=Product.objects.all(), source='product')

    class Meta:
        model = Favorite
        fields = ('id', 'user', 'product', 'product_id', 'created_at')
        read_only_fields = ('id', 'user', 'product', 'created_at')


class ProductViewSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    product = ProductSerializer(read_only=True)

    class Meta:
        model = ProductView
        fields = ('id', 'user', 'product', 'viewed_at')
        read_only_fields = ('id', 'user', 'product', 'viewed_at')


class RecommendationSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    product = ProductSerializer(read_only=True)

    class Meta:
        model = Recommendation
        fields = ('id', 'user', 'product', 'score', 'reason', 'created_at')
        read_only_fields = ('id', 'user', 'product', 'score', 'reason', 'created_at')


class PostVideoField(serializers.FileField):
    def to_representation(self, value):
        if value:
            name = getattr(value, 'name', None)
            if isinstance(name, str) and name.startswith(('http://', 'https://')):
                return name
        return super().to_representation(value)


class PostSerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    video = PostVideoField(required=False, allow_null=True)
    background_color = serializers.RegexField(
        regex=r'^#[0-9A-Fa-f]{6}$',
        required=False,
        allow_blank=True,
    )
    likes_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    shares_count = serializers.SerializerMethodField()
    category_name = serializers.CharField(source='category.name', read_only=True)
    product_title = serializers.CharField(source='product.title', read_only=True)
    tagged_users = UserWithProfileSerializer(many=True, read_only=True)
    trophy_data = serializers.JSONField(read_only=True)
    is_liked = serializers.SerializerMethodField()
    reactions = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = ('id', 'author', 'content', 'post_type', 'background_color', 'image', 'video', 'images', 'product', 'product_title', 'category', 'category_name', 'privacy', 'location', 'latitude', 'longitude', 'is_active', 'likes_count', 'comments_count', 'shares_count', 'repost_of', 'tagged_users', 'hashtags', 'is_liked', 'reactions', 'trophy_data', 'created_at')
        read_only_fields = ('id', 'author', 'is_active', 'likes_count', 'comments_count', 'shares_count', 'is_liked', 'reactions', 'created_at')

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_comments_count(self, obj):
        return obj.comments.count()

    def get_shares_count(self, obj):
        return obj.shares.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_reactions(self, obj):
        reactions = obj.reactions.values('reaction_type').annotate(count=models.Count('reaction_type')).order_by('-count')
        return {reaction['reaction_type']: reaction['count'] for reaction in reactions}


class LikeSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = Like
        fields = ('id', 'user', 'post', 'created_at')


class CommentSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = Comment
        fields = ('id', 'user', 'post', 'content', 'created_at')


class ProducerReviewSerializer(serializers.ModelSerializer):
    reviewer = UserWithProfileSerializer(source='user', read_only=True)
    producer = UserWithProfileSerializer(read_only=True)
    producer_id = serializers.PrimaryKeyRelatedField(write_only=True, queryset=User.objects.all(), source='producer')

    class Meta:
        model = ProducerReview
        fields = ('id', 'producer', 'producer_id', 'reviewer', 'rating', 'comment', 'created_at')
        read_only_fields = ('id', 'producer', 'reviewer', 'created_at')


# Sérialiseurs pour coupons et fidélité
class CouponSerializer(serializers.ModelSerializer):
    class Meta:
        model = Coupon
        fields = ('id', 'code', 'discount_type', 'discount_value', 'min_order_value', 'max_discount', 'usage_limit', 'used_count', 'valid_from', 'valid_until', 'is_active')


class LoyaltyProgramSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = LoyaltyProgram
        fields = ('id', 'user', 'points')


class ReferralSerializer(serializers.ModelSerializer):
    referrer = UserWithProfileSerializer(read_only=True)
    referred = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = Referral
        fields = ('id', 'referrer', 'referred', 'bonus_points', 'created_at')


# Nouveaux sérialiseurs pour le réseau social étendu
class ShareSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    post = PostSerializer(read_only=True)
    post_id = serializers.PrimaryKeyRelatedField(
        source='post',
        queryset=Post.objects.filter(is_active=True, privacy='public'),
        write_only=True,
    )

    class Meta:
        model = Share
        fields = ('id', 'user', 'post', 'post_id', 'content', 'created_at')
        read_only_fields = ('id', 'user', 'created_at')


class JobPostingSerializer(serializers.ModelSerializer):
    employer = UserWithProfileSerializer(read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = JobPosting
        fields = ('id', 'employer', 'title', 'description', 'company', 'location', 'salary_min', 'salary_max', 'job_type', 'category', 'category_name', 'is_active', 'applications_count', 'created_at')
        read_only_fields = ('id', 'employer', 'applications_count', 'created_at')


class JobSeekerPostSerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    resume = serializers.FileField(
        required=False,
        allow_null=True,
        write_only=True,
        allow_empty_file=False,
    )
    has_resume = serializers.SerializerMethodField()

    class Meta:
        model = JobSeekerPost
        fields = (
            'id',
            'author',
            'title',
            'description',
            'location',
            'job_type',
            'resume',
            'has_resume',
            'created_at',
        )
        read_only_fields = ('id', 'author', 'created_at')

    def get_has_resume(self, obj):
        return bool(obj.resume)

    def validate_resume(self, value):
        _validate_job_resume(value)
        return value


def _validate_job_resume(value):
    extension = value.name.rsplit('.', 1)[-1].lower()
    if extension not in ('pdf', 'png', 'jpg', 'jpeg'):
        raise serializers.ValidationError(
            'Le CV doit être au format PDF, PNG ou JPEG.',
        )
    if value.size > 10 * 1024 * 1024:
        raise serializers.ValidationError('Le CV ne peut pas dépasser 10 Mo.')
    signature = value.read(8)
    value.seek(0)
    valid_signature = (
        signature.startswith(b'%PDF-')
        if extension == 'pdf'
        else signature.startswith(b'\x89PNG\r\n\x1a\n')
        if extension == 'png'
        else signature.startswith(b'\xff\xd8\xff')
    )
    if not valid_signature:
        raise serializers.ValidationError(
            'Le contenu du CV ne correspond pas à son format.',
        )


class JobApplicationSerializer(serializers.ModelSerializer):
    applicant = UserWithProfileSerializer(read_only=True)
    job = JobPostingSerializer(read_only=True)
    job_id = serializers.PrimaryKeyRelatedField(
        source='job',
        queryset=JobPosting.objects.filter(is_active=True),
        write_only=True,
    )
    cover_letter = serializers.CharField(required=True, allow_blank=False)
    resume = serializers.FileField(
        required=True,
        allow_empty_file=False,
        write_only=True,
    )
    has_resume = serializers.SerializerMethodField()

    class Meta:
        model = JobApplication
        fields = (
            'id',
            'applicant',
            'job',
            'job_id',
            'cover_letter',
            'resume',
            'has_resume',
            'status',
            'created_at',
        )
        read_only_fields = ('id', 'applicant', 'status', 'created_at')
        validators = []

    def get_has_resume(self, obj):
        return bool(obj.resume)

    def validate_job_id(self, job):
        request = self.context.get('request')
        if request is not None and request.user == job.employer:
            raise serializers.ValidationError(
                'Vous ne pouvez pas postuler à votre propre offre.',
            )
        return job

    def validate_cover_letter(self, value):
        if not value.strip():
            raise serializers.ValidationError(
                'Ajoutez une description à votre candidature.',
            )
        return value

    def validate_resume(self, value):
        _validate_job_resume(value)
        return value


class ProfileRoleChangeSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=PROFILE_ROLE_CHANGE_CHOICES)


# Serializers pour les groupes/communautés
class GroupSerializer(serializers.ModelSerializer):
    creator = UserWithProfileSerializer(read_only=True)
    category = CategorySerializer(read_only=True)
    category_name = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    is_member = serializers.SerializerMethodField()
    member_status = serializers.SerializerMethodField()
    member_role = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = ('id', 'name', 'slug', 'description', 'cover_image', 'avatar', 'group_type',
                 'creator', 'category', 'category_name',
                 'rules', 'is_active', 'member_count', 'is_member', 'member_status', 'member_role',
                 'created_at', 'updated_at')
        read_only_fields = ('id', 'slug', 'creator', 'member_count', 'is_member', 'member_status', 'member_role', 'created_at', 'updated_at')

    def get_category_name(self, obj):
        if obj.category is None:
            return None
        serialized = CategorySerializer(obj.category, context=self.context).data
        return serialized.get('translated_name') or serialized.get('name')

    def get_member_count(self, obj):
        return obj.member_count

    def get_is_member(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.members.filter(user=request.user, is_active=True).exists()
        return False

    def get_member_status(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            membership = obj.members.filter(user=request.user).first()
            if membership is None:
                return None
            return 'approved' if membership.is_active else 'pending'
        return None

    def get_member_role(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            membership = obj.members.filter(user=request.user, is_active=True).first()
            return membership.role if membership else None
        return None


class GroupCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Group
        fields = ('name', 'description', 'cover_image', 'avatar', 'group_type', 'category',
                 'rules')

    def create(self, validated_data):
        validated_data['creator'] = self.context['request'].user
        return super().create(validated_data)


class GroupMemberSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    group_name = serializers.CharField(source='group.name', read_only=True)

    class Meta:
        model = GroupMember
        fields = ('id', 'group', 'group_name', 'user', 'is_active', 'role', 'joined_at')
        read_only_fields = ('id', 'joined_at')


class GroupMemberCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroupMember
        fields = ('group',)

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class GroupPostSerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    group_name = serializers.CharField(source='group.name', read_only=True)
    likes_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    reposts_count = serializers.SerializerMethodField()
    tagged_users = UserWithProfileSerializer(many=True, read_only=True)
    is_liked = serializers.SerializerMethodField()
    reactions = serializers.SerializerMethodField()

    class Meta:
        model = GroupPost
        fields = ('id', 'group', 'group_name', 'author', 'content', 'post_type', 'privacy',
                 'image', 'video', 'images', 'event', 'poll_question', 'poll_options',
                 'poll_results', 'is_pinned', 'is_announcement', 'is_active',
                 'likes_count', 'comments_count', 'reposts_count', 'tagged_users', 'hashtags',
                 'is_liked', 'reactions', 'created_at', 'updated_at')
        read_only_fields = ('id', 'author', 'likes_count', 'comments_count', 'reposts_count', 'is_liked', 'reactions', 'created_at', 'updated_at')

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_comments_count(self, obj):
        return obj.comments.filter(is_active=True).count()

    def get_reposts_count(self, obj):
        return obj.reposts.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_reactions(self, obj):
        reactions = obj.reactions.values('reaction_type').annotate(count=models.Count('reaction_type')).order_by('-count')
        return {reaction['reaction_type']: reaction['count'] for reaction in reactions}


class GroupPostCreateSerializer(serializers.ModelSerializer):
    group = serializers.PrimaryKeyRelatedField(queryset=Group.objects.all(), pk_field=serializers.IntegerField())

    class Meta:
        model = GroupPost
        fields = ('id', 'group', 'content', 'post_type', 'privacy', 'image', 'video', 'images',
                 'event', 'poll_question', 'poll_options', 'is_pinned',
                 'is_announcement', 'tagged_users', 'hashtags', 'repost_of')
        read_only_fields = ('id',)

    def create(self, validated_data):
        validated_data['author'] = self.context['request'].user
        request = self.context.get('request')
        
        # Create the post first
        post = super().create(validated_data)
        
        # Handle multiple images if provided
        if request and request.FILES:
            from django.core.files.storage import default_storage
            import os
            
            images_urls = []
            
            # Check for the main image
            if post.image:
                images_urls.append(post.image.url if post.image.url.startswith('http') else f'/media/{post.image}')
            
            # Check for additional images (image_1, image_2, etc.)
            image_index = 1
            while f'image_{image_index}' in request.FILES:
                file = request.FILES[f'image_{image_index}']
                # Store each additional image
                filename = f'group_posts/{post.id}/image_{image_index}_{file.name}'
                path = default_storage.save(filename, file)
                # Store relative path to be used by the media URL builder
                images_urls.append(f'/media/{path}')
                image_index += 1
            
            # If we have multiple images, update the post to album type
            if len(images_urls) > 1:
                post.images = images_urls
                post.post_type = 'album'
                post.save(update_fields=['images', 'post_type'])
            elif len(images_urls) == 1 and post.image:
                # Single image was provided, update images field for consistency
                post.images = images_urls
                post.save(update_fields=['images'])
        
        return post


class GroupPostUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroupPost
        fields = ('content', 'post_type', 'privacy', 'image', 'video', 'images',
                 'poll_question', 'poll_options', 'is_pinned', 'is_announcement')
        read_only_fields = ()


class GroupPostLikeSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = GroupPostLike
        fields = ('id', 'post', 'user', 'created_at')
        read_only_fields = ('id', 'user', 'created_at')


class GroupPostCommentSerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = GroupPostComment
        fields = ('id', 'post', 'author', 'content', 'is_liked',
                 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('id', 'author', 'is_liked', 'created_at', 'updated_at')

    def get_is_liked(self, obj):
        # Pour l'instant, pas de système de likes sur les commentaires
        return False


class GroupPostCommentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroupPostComment
        fields = ('post', 'content')

    def create(self, validated_data):
        validated_data['author'] = self.context['request'].user
        return super().create(validated_data)


class GroupEventSerializer(serializers.ModelSerializer):
    creator = UserWithProfileSerializer(read_only=True)
    group_name = serializers.CharField(
        source='group.name',
        read_only=True,
        allow_null=True,
    )
    attendees_count = serializers.SerializerMethodField()
    is_attending = serializers.SerializerMethodField()
    attendance_status = serializers.SerializerMethodField()

    class Meta:
        model = GroupEvent
        fields = ('id', 'group', 'group_name', 'creator', 'title', 'description', 'start_date',
                 'end_date', 'location', 'latitude', 'longitude', 'max_attendees', 'attendees_count',
                 'is_attending', 'attendance_status', 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('id', 'creator', 'attendees_count', 'is_attending', 'attendance_status', 'created_at', 'updated_at')

    def get_attendees_count(self, obj):
        return obj.attendees.filter(status='going').count()

    def get_is_attending(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.attendees.filter(user=request.user, status='going').exists()
        return False

    def get_attendance_status(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            attendance = obj.attendees.filter(user=request.user).first()
            return attendance.status if attendance else None
        return None


class GroupEventCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroupEvent
        fields = ('group', 'title', 'description', 'start_date', 'end_date', 'location',
                 'latitude', 'longitude', 'max_attendees')

    def create(self, validated_data):
        validated_data['creator'] = self.context['request'].user
        return super().create(validated_data)

    def validate(self, attrs):
        start_date = attrs.get('start_date')
        end_date = attrs.get('end_date')
        if start_date and end_date and end_date <= start_date:
            raise serializers.ValidationError({
                'end_date': 'La date de fin doit être après la date de début.'
            })
        return attrs


class GroupEventAttendeeSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)
    event_title = serializers.CharField(source='event.title', read_only=True)

    class Meta:
        model = GroupEventAttendee
        fields = ('id', 'event', 'event_title', 'user', 'status', 'created_at')
        read_only_fields = ('id', 'user', 'created_at')


# Stories serializers
class StorySerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    views_count = serializers.SerializerMethodField()
    likes_count = serializers.SerializerMethodField()
    is_viewed = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    is_expired = serializers.SerializerMethodField()

    class Meta:
        model = Story
        fields = ('id', 'author', 'story_type', 'content', 'image', 'video',
                 'background_color', 'text_color', 'font_size', 'expires_at',
                 'views_count', 'likes_count', 'is_viewed', 'is_liked', 'is_expired', 'created_at')
        read_only_fields = ('id', 'author', 'views_count', 'likes_count', 'is_viewed', 'is_liked', 'is_expired', 'created_at')

    def get_views_count(self, obj):
        return obj.views.count()

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_is_viewed(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.views.filter(viewer=request.user).exists()
        return False

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_is_expired(self, obj):
        return obj.is_expired


class StoryCreateSerializer(StorySerializer):
    class Meta(StorySerializer.Meta):
        extra_kwargs = {
            'expires_at': {'required': False}
        }
        read_only_fields = StorySerializer.Meta.read_only_fields + ('expires_at',)

    def create(self, validated_data):
        from django.utils import timezone

        # Forcer l'expiration à 24 heures à partir de la création
        validated_data['expires_at'] = timezone.now() + timedelta(hours=24)
        validated_data['author'] = self.context['request'].user
        return super().create(validated_data)


class StoryViewSerializer(serializers.ModelSerializer):
    viewer = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = StoryView
        fields = ('id', 'viewer', 'story', 'created_at')
        read_only_fields = ('id', 'viewer', 'created_at')


class StoryLikeSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = StoryLike
        fields = ('id', 'user', 'story', 'created_at')
        read_only_fields = ('id', 'user', 'created_at')


# Reels serializers
class ReelSerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    is_liked = serializers.SerializerMethodField()
    is_viewed = serializers.SerializerMethodField()

    class Meta:
        model = Reel
        fields = ('id', 'author', 'title', 'description', 'video', 'thumbnail',
                 'theme', 'effect', 'sticker', 'duration', 'views_count',
                 'likes_count', 'comments_count',
                 'shares_count', 'audio_title', 'audio_artist', 'is_liked',
                 'is_viewed', 'created_at')
        read_only_fields = ('id', 'author', 'views_count', 'likes_count',
                           'comments_count', 'shares_count', 'is_liked',
                           'is_viewed', 'created_at')

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_is_viewed(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.views.filter(viewer=request.user).exists()
        return False


class ReelCreateSerializer(serializers.ModelSerializer):
    before_video = serializers.FileField(required=False, write_only=True)

    class Meta:
        model = Reel
        fields = (
            'title',
            'description',
            'video',
            'before_video',
            'thumbnail',
            'theme',
            'effect',
            'sticker',
            'duration',
            'audio_title',
            'audio_artist',
        )
        read_only_fields = ('duration',)

    def validate(self, attrs):
        effect = attrs.get('effect', 'none')
        before_video = attrs.get('before_video')
        if effect == 'before_after' and before_video is None:
            raise serializers.ValidationError(
                {'before_video': 'Choisissez la vidéo « avant ».'}
            )
        if effect != 'before_after' and before_video is not None:
            raise serializers.ValidationError(
                {'before_video': 'Ce fichier est réservé au montage avant/après.'}
            )
        if effect == 'stickers' and not attrs.get('sticker'):
            raise serializers.ValidationError(
                {'sticker': 'Choisissez un autocollant à ajouter.'}
            )
        return attrs

    def create(self, validated_data):
        from core.reel_video_effects import (
            ReelVideoProcessingError,
            process_reel_video,
        )

        before_video = validated_data.pop('before_video', None)
        effect = validated_data.get('effect', 'none')
        sticker = validated_data.get('sticker', '')
        try:
            processed_video, duration, thumbnail = process_reel_video(
                validated_data['video'],
                effect=effect,
                sticker=sticker,
                before_video=before_video,
            )
        except ReelVideoProcessingError as error:
            raise serializers.ValidationError({'video': str(error)}) from error

        try:
            validated_data['video'] = processed_video
            validated_data['thumbnail'] = thumbnail
            validated_data['duration'] = timedelta(
                seconds=max(1, round(duration))
            )
            validated_data['author'] = self.context['request'].user
            return super().create(validated_data)
        finally:
            processed_video.close()
            thumbnail.close()


class ReelCommentSerializer(serializers.ModelSerializer):
    author = UserWithProfileSerializer(read_only=True)
    replies_count = serializers.SerializerMethodField()

    class Meta:
        model = ReelComment
        fields = ('id', 'reel', 'author', 'content', 'parent', 'replies_count',
                 'likes_count', 'is_active', 'created_at')
        read_only_fields = ('id', 'author', 'replies_count', 'created_at')

    def get_replies_count(self, obj):
        return obj.replies.count()


# Reactions serializer
class ReactionSerializer(serializers.ModelSerializer):
    user = UserWithProfileSerializer(read_only=True)

    class Meta:
        model = Reaction
        fields = ('id', 'user', 'post', 'group_post', 'reel', 'reaction_type', 'created_at')
        read_only_fields = ('id', 'user', 'created_at')


# Marketplace serializers
class MarketplaceListingSerializer(serializers.ModelSerializer):
    seller = UserWithProfileSerializer(read_only=True)
    product_title = serializers.CharField(source='product.title', read_only=True)
    product_images = serializers.SerializerMethodField()
    is_favorited = serializers.SerializerMethodField()

    class Meta:
        model = MarketplaceListing
        fields = ('id', 'seller', 'product', 'product_title', 'product_images',
                 'title', 'description', 'price', 'condition', 'location',
                 'latitude', 'longitude', 'is_active', 'views_count',
                 'favorites_count', 'is_favorited', 'created_at')
        read_only_fields = ('id', 'seller', 'views_count', 'favorites_count',
                           'is_favorited', 'created_at')

    def get_product_images(self, obj):
        return [image.image.url for image in obj.product.images.all()]

    def get_is_favorited(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.favorites.filter(user=request.user).exists()
        return False


# Hashtags serializer
class HashtagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hashtag
        fields = ('id', 'name', 'usage_count', 'created_at')
        read_only_fields = ('id', 'usage_count', 'created_at')


# Cart and Shopping Serializers
class CartItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.IntegerField(write_only=True)
    subtotal = serializers.SerializerMethodField()
    price = serializers.SerializerMethodField()
    selected_color = serializers.CharField(required=False, allow_blank=True, max_length=80)
    selected_size = serializers.CharField(required=False, allow_blank=True, max_length=80)

    class Meta:
        model = CartItem
        fields = ('id', 'product', 'product_id', 'quantity', 'selected_color', 'selected_size', 'price', 'subtotal', 'created_at')
        read_only_fields = ('id', 'price', 'created_at')

    def validate(self, attrs):
        product = Product.objects.filter(id=attrs.get('product_id')).first()
        if product is not None:
            for field, option_field in (
                ('selected_color', 'color_options'),
                ('selected_size', 'size_options'),
            ):
                value = attrs.get(field, '')
                options = getattr(product, option_field)
                if options and value not in options:
                    raise serializers.ValidationError(
                        {field: 'Veuillez choisir une option disponible pour ce produit.'}
                    )
                if not options and value:
                    raise serializers.ValidationError(
                        {field: 'Cette option n’est pas proposée pour ce produit.'}
                    )
        return attrs

    def get_subtotal(self, obj):
        return obj.product.current_price * obj.quantity

    def get_price(self, obj):
        return obj.product.current_price

    def create(self, validated_data):
        product_id = validated_data.pop('product_id')
        product = Product.objects.get(id=product_id)
        validated_data['product'] = product
        validated_data['price'] = product.current_price
        return super().create(validated_data)


class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(many=True, read_only=True)
    item_count = serializers.SerializerMethodField()
    total = serializers.SerializerMethodField()

    class Meta:
        model = Cart
        fields = ('id', 'items', 'total', 'item_count', 'created_at', 'updated_at')
        read_only_fields = ('id', 'total', 'created_at', 'updated_at')

    def get_item_count(self, obj):
        return obj.item_count

    def get_total(self, obj):
        return sum(
            (
                item.product.current_price * item.quantity
                for item in obj.items.select_related('product')
            ),
            start=0,
        )


class ProductDetailSerializer(serializers.ModelSerializer):
    """Serializer complet pour les détails d'un produit"""
    shop = ShopSerializer(read_only=True)
    category = serializers.StringRelatedField(read_only=True)
    images = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    is_favorited = serializers.SerializerMethodField()
    is_in_cart = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = ('id', 'shop', 'category', 'title', 'description', 'price',
                 'promo_price', 'current_price', 'is_on_promotion', 'color_options', 'size_options', 'quantity', 'image', 'images', 'video', 'is_active',
                 'average_rating', 'is_favorited', 'is_in_cart',
                 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')

    def get_images(self, obj):
        """Retourne toutes les images du produit"""
        images = obj.images.all()
        return [{'id': img.id, 'image': img.image.url, 'order': img.order} 
                for img in images]

    def get_average_rating(self, obj):
        """Calcule la note moyenne du produit"""
        # Si le modèle Product a une relation reviews, utiliser celle-ci
        if hasattr(obj, 'reviews') and obj.reviews.exists():
            return sum(r.rating for r in obj.reviews.all()) / obj.reviews.count()
        return 0
        return 0

    def get_is_favorited(self, obj):
        """Vérifie si l'utilisateur a aimé ce produit"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Favorite.objects.filter(user=request.user, product=obj).exists()
        return False

    def get_is_in_cart(self, obj):
        """Vérifie si le produit est dans le panier de l'utilisateur"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                cart = Cart.objects.get(user=request.user)
                return CartItem.objects.filter(cart=cart, product=obj).exists()
            except Cart.DoesNotExist:
                pass
        return False


class ProfileChangeSerializer(serializers.ModelSerializer):
    """Serializer pour changer le profil de l'utilisateur"""
    new_role = serializers.ChoiceField(
        choices=UserProfile.ROLE_CHOICES,
        write_only=True
    )

    class Meta:
        model = UserProfile
        fields = ('new_role', 'phone', 'address', 'city', 'country', 
                 'company_name', 'company_registration', 'tax_id')

    def update(self, instance, validated_data):
        new_role = validated_data.pop('new_role', None)
        if new_role:
            instance.role = new_role
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance
