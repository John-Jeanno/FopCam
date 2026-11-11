from rest_framework import permissions


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Autorise les actions en écriture uniquement au propriétaire lié à l'objet (shop owner, post author, etc.) or staff."""

    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed to any request
        if request.method in permissions.SAFE_METHODS:
            return True

        # If the object has 'author' attribute (Post, Comment, etc.)
        author = getattr(obj, 'author', None)
        if author is not None:
            return request.user and (request.user == author or request.user.is_staff)

        # If the object has 'owner' attribute (Shop)
        owner = getattr(obj, 'owner', None)
        if owner is not None:
            return request.user and (request.user == owner or request.user.is_staff)

        # If the object has 'user' attribute (UserProfile, etc.)
        user = getattr(obj, 'user', None)
        if user is not None:
            return request.user and (request.user == user or request.user.is_staff)

        # If the object has 'shop' attribute (Product, OrderItem etc.)
        shop = getattr(obj, 'shop', None)
        if shop is not None and hasattr(shop, 'owner'):
            return request.user and (request.user == shop.owner or request.user.is_staff)

        return False


class IsGroupAdminOrReadOnly(permissions.BasePermission):
    """Autorise les modifications seulement au créateur/admin du groupe."""

    def has_object_permission(self, request, view, obj):
        # Read permissions allowed to any request
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions only for group admin or creator
        if hasattr(obj, 'creator') and hasattr(obj, 'members'):
            # Vérifier si l'utilisateur est admin du groupe
            is_admin = obj.members.filter(
                user=request.user,
                role='admin',
                is_active=True
            ).exists()
            return is_admin or request.user.is_staff
        
        return False


class CanAccessSecretGroup(permissions.BasePermission):
    """Autorise l'accès aux groupes secrets seulement aux membres."""

    def has_object_permission(self, request, view, obj):
        if not hasattr(obj, 'group_type') or obj.group_type != 'secret':
            return True
        
        # Pour les groupes secrets, vérifier que l'utilisateur est membre actif
        if hasattr(obj, 'members'):
            is_member = obj.members.filter(
                user=request.user,
                is_active=True
            ).exists()
            return is_member or request.user.is_staff
        
        return False

