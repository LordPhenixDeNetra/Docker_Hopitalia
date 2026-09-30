-- ============================================================
-- Initialisation du compte ADMIN (premier déploiement)
-- A lancer APRES le premier démarrage de l'app (ddl-auto: update crée les tables).
-- Rejouable sans risque : rien n'est dupliqué.
-- Connexion : login = admin
-- ============================================================
BEGIN;

-- 1. Rôles (les ids sont générés par la base, on travaille par nom)
INSERT INTO role (name) VALUES
    ('ADMINISTRATEUR'),
    ('MEDECIN'),
    ('CHEF_DE_SERVICE'),
    ('CAISSIER'),
    ('FACTURIER'),
    ('ARCHIVISTE'),
    ('SECRETAIRE'),
    ('GESTIONNAIRE_DES_ADMISSIONS'),
    ('INFIRMIER'),
    ('COMPTABILITE'),
    ('PHARMACIE_AGENT'),
    ('PHARMACIE_ADMIN'),
    ('CAISSIER_CHEF'),
    ('PHARMACIE_RESPONSABLE'),
    ('SUPER_ADMIN'),
    ('BUREAU_DES_ENTREES'),
    ('BUREAU_DES_ENTREES_CHEF'),
    ('BUREAU_DES_ENTREES_AGENT'),
    ('CAISSIER_AGENT')
ON CONFLICT (name) DO NOTHING;

-- 2. Service ADMINISTRATION
INSERT INTO service (code_service, nom_service, afficher, administration, laboratoire)
VALUES ('ADMIN', 'ADMINISTRATION', true, true, false)
ON CONFLICT (code_service) DO NOTHING;

-- 3. Spécialité ADMINISTRATION rattachée au service
INSERT INTO specialite (code_specialite, nom_specialite, nom_service, code_service, service_id, pharme_lb)
SELECT 'ADMIN', 'ADMINISTRATION', s.nom_service, s.code_service, s.id, false
FROM service s
WHERE s.code_service = 'ADMIN'
ON CONFLICT (code_specialite) DO NOTHING;

-- 4. Agent admin (compte actif : est_bloquer = false)
INSERT INTO agent (code_agent, nom, prenom, login, mot_de_passe, est_bloquer, libelle_type, date_maj, specialite_id)
SELECT 'ADMIN', 'ADMIN', 'Administrateur', 'admin',
       '$2a$10$N4dpkWCHxnIXMoH68NMIDuHRw15mM9dXFxQG6Zba6pqg/ci8DvYdO',
       false, 'ADMINISTRATION', CURRENT_DATE, sp.id
FROM specialite sp
WHERE sp.code_specialite = 'ADMIN'
ON CONFLICT (code_agent) DO UPDATE SET est_bloquer = false;

-- 5. Rôles de l'admin
INSERT INTO agent_roles (agent_id, role_id)
SELECT a.id, r.id
FROM agent a
JOIN role r ON r.name IN ('SUPER_ADMIN', 'ADMINISTRATEUR')
WHERE a.code_agent = 'ADMIN'
ON CONFLICT DO NOTHING;

COMMIT;

-- Vérification
SELECT a.id, a.code_agent, a.login, a.est_bloquer, sp.nom_specialite, string_agg(r.name, ', ') AS roles
FROM agent a
LEFT JOIN specialite sp ON sp.id = a.specialite_id
LEFT JOIN agent_roles ar ON ar.agent_id = a.id
LEFT JOIN role r ON r.id = ar.role_id
WHERE a.code_agent = 'ADMIN'
GROUP BY a.id, a.code_agent, a.login, a.est_bloquer, sp.nom_specialite;
