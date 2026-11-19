-- ============================================================
-- Initialisation RBAC (premier déploiement)
-- A lancer APRES le premier démarrage de l'app (ddl-auto: update crée les tables).
-- Rejouable sans risque : rien n'est dupliqué.
--
-- NOUVEAU MODELE RBAC (contrôle par permissions) :
--   - role.systeme       : TRUE = rôle système non supprimable (SUPER_ADMIN).
--   - permission         : catalogue centralisé (code = RESSOURCE_ACTION).
--   - role_permission    : lien rôle -> permissions.
--   - agent_roles        : lien agent -> rôles.
--   - agent_permission   : surcharge exceptionnelle d'un agent (optionnelle).
--
-- SOURCE DE VERITE :
--   Le catalogue complet des permissions (énumération PermissionCode) et
--   l'attribution fine rôle -> permissions sont gérés par `RbacDataInitializer`
--   (CommandLineRunner) au démarrage de l'application. Ce script ne duplique
--   PAS ce catalogue : il crée les rôles, marque SUPER_ADMIN comme rôle système,
--   lui accorde toutes les permissions déjà présentes en base, puis crée le
--   compte admin initial et les référentiels ADMINISTRATION.
--
-- Connexion admin : login = admin
--   (mot de passe configuré via app.admin.password, défaut : admin123)
-- ============================================================
BEGIN;

-- 1. Rôles (nouvelle règle : colonne `systeme`)
INSERT INTO role (name, description, systeme) VALUES
    ('SUPER_ADMIN',                 'Rôle système disposant de toutes les permissions', TRUE),
    ('ADMINISTRATEUR',              'Administrateur général',                            FALSE),
    ('MEDECIN',                     'Médecin',                                            FALSE),
    ('CHEF_DE_SERVICE',             'Chef de service',                                    FALSE),
    ('CAISSIER',                    'Caissier',                                           FALSE),
    ('CAISSIER_CHEF',               'Caissier chef',                                      FALSE),
    ('CAISSIER_AGENT',              'Caissier agent',                                     FALSE),
    ('FACTURIER',                   'Facturier',                                          FALSE),
    ('FACTURIER_CHEF',              'Facturier chef',                                     FALSE),
    ('ARCHIVISTE',                  'Archiviste',                                         FALSE),
    ('SECRETAIRE',                  'Secrétaire',                                         FALSE),
    ('GESTIONNAIRE_DES_ADMISSIONS', 'Gestionnaire des admissions',                        FALSE),
    ('INFIRMIER',                   'Infirmier',                                          FALSE),
    ('COMPTABILITE',                'Comptabilité',                                       FALSE),
    ('COMPTABILITE_CHEF',           'Comptabilité chef',                                  FALSE),
    ('COMPTABILITE_AGENT',          'Comptabilité agent',                                 FALSE),
    ('COMPTABILITE_AGENT_SUPP',     'Comptabilité agent supplément',                      FALSE),
    ('PHARMACIE_AGENT',             'Pharmacie agent',                                    FALSE),
    ('PHARMACIE_ADMIN',             'Pharmacie admin',                                    FALSE),
    ('PHARMACIE_RESPONSABLE',       'Pharmacie responsable',                              FALSE),
    ('BUREAU_DES_ENTREES',          'Bureau des entrées',                                 FALSE),
    ('BUREAU_DES_ENTREES_CHEF',     'Bureau des entrées chef',                            FALSE),
    ('BUREAU_DES_ENTREES_AGENT',    'Bureau des entrées agent',                           FALSE)
ON CONFLICT (name) DO NOTHING;

-- SUPER_ADMIN est toujours un rôle système (non supprimable depuis l'interface).
UPDATE role SET systeme = TRUE WHERE name = 'SUPER_ADMIN';

-- 2. SUPER_ADMIN : accorder toutes les permissions déjà présentes en base.
--    (les permissions manquantes sont créées au démarrage par RbacDataInitializer)
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r
CROSS JOIN permission p
WHERE r.name = 'SUPER_ADMIN'
  AND NOT EXISTS (
      SELECT 1 FROM role_permission rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- 3. Service ADMINISTRATION
INSERT INTO service (code_service, nom_service, afficher, administration, laboratoire)
VALUES ('ADMIN', 'ADMINISTRATION', true, true, false)
ON CONFLICT (code_service) DO NOTHING;

-- 4. Spécialité ADMINISTRATION rattachée au service
INSERT INTO specialite (code_specialite, nom_specialite, nom_service, code_service, service_id, pharme_lb)
SELECT 'ADMIN', 'ADMINISTRATION', s.nom_service, s.code_service, s.id, false
FROM service s
WHERE s.code_service = 'ADMIN'
ON CONFLICT (code_specialite) DO NOTHING;

-- 5. Agent admin (compte système : rôle SUPER_ADMIN uniquement, plus ADMINISTRATEUR)
INSERT INTO agent (code_agent, nom, prenom, login, mot_de_passe, est_bloquer, libelle_type, date_maj, specialite_id)
SELECT 'ADMIN', 'ADMIN', 'Administrateur', 'admin',
       '$2a$10$N4dpkWCHxnIXMoH68NMIDuHRw15mM9dXFxQG6Zba6pqg/ci8DvYdO',
       false, 'ADMINISTRATION', CURRENT_DATE, sp.id
FROM specialite sp
WHERE sp.code_specialite = 'ADMIN'
ON CONFLICT (code_agent) DO UPDATE SET est_bloquer = false;

-- 6. Rôle SUPER_ADMIN de l'admin
INSERT INTO agent_roles (agent_id, role_id)
SELECT a.id, r.id
FROM agent a
JOIN role r ON r.name = 'SUPER_ADMIN'
WHERE a.code_agent = 'ADMIN'
ON CONFLICT DO NOTHING;

COMMIT;

-- Vérification
SELECT a.id, a.code_agent, a.login, a.est_bloquer,
       string_agg(r.name, ', ' ORDER BY r.name) AS roles
FROM agent a
LEFT JOIN agent_roles ar ON ar.agent_id = a.id
LEFT JOIN role r ON r.id = ar.role_id
WHERE a.code_agent = 'ADMIN'
GROUP BY a.id, a.code_agent, a.login, a.est_bloquer;
