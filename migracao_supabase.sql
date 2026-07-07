-- SCRIPT DE MIGRAÇÃO COMPLETO - AGROGESTÃO V2
-- Execute este script no SQL Editor do seu novo projeto Supabase.

-- 1. EXTENSÕES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. FUNÇÕES DE SEGURANÇA E SUPORTE
CREATE OR REPLACE FUNCTION public.get_my_tenant_ids()
 RETURNS uuid[]
 LANGUAGE sql
 STABLE
AS $function$
  SELECT ARRAY(
    SELECT tenant_id
    FROM public.user_tenants
    WHERE user_id = auth.uid()
  )
$function$;

-- 3. TABELAS BASE
CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    nome text NOT NULL,
    slug text UNIQUE,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_tenants (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id),
    tenant_id uuid REFERENCES public.tenants(id),
    role text DEFAULT 'member',
    criado_em timestamptz DEFAULT now(),
    UNIQUE(user_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS public.culturas (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    nome text NOT NULL,
    tipo text,
    unidade_producao text,
    unidade_area text,
    icone text,
    ativo boolean DEFAULT true,
    settings jsonb,
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.lotes (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    cultura_id uuid REFERENCES public.culturas(id),
    nome text,
    variedade text,
    area_ha numeric,
    status text DEFAULT 'ativo',
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.setores (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    lote_id uuid REFERENCES public.lotes(id),
    nome text NOT NULL,
    cultura text,
    variedade text,
    area_ha numeric,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.insumos (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    nome text NOT NULL,
    unidade text NOT NULL,
    categoria text,
    estoque_atual numeric DEFAULT 0,
    estoque_minimo numeric DEFAULT 0,
    custo_medio numeric DEFAULT 0,
    status text DEFAULT 'ativo',
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now(),
    atualizado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.contas_financeiras (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    nome text NOT NULL,
    tipo text NOT NULL,
    saldo_atual numeric DEFAULT 0,
    ativo boolean DEFAULT true,
    criado_em timestamptz DEFAULT now(),
    atualizado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.clients (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    nome text NOT NULL,
    cpf_cnpj text,
    telefone text,
    email text,
    observacoes text,
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.suppliers (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    nome text NOT NULL,
    categoria text,
    telefone text,
    email text,
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendas (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    client_id uuid REFERENCES public.clients(id),
    carga_id uuid,
    data_venda date NOT NULL,
    valor_total numeric DEFAULT 0,
    valor_liquido numeric DEFAULT 0,
    status_pagamento text DEFAULT 'pendente',
    data_vencimento date,
    comprador text,
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.custos (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id uuid REFERENCES public.tenants(id),
    lote_id uuid REFERENCES public.lotes(id),
    supplier_id uuid REFERENCES public.suppliers(id),
    descricao text NOT NULL,
    categoria text,
    valor numeric DEFAULT 0,
    data_custo date NOT NULL,
    data_vencimento date,
    status_pagamento text DEFAULT 'pendente',
    pago boolean DEFAULT false,
    deleted_at timestamptz,
    criado_em timestamptz DEFAULT now()
);

-- 4. FUNÇÕES DE NEGÓCIO
CREATE OR REPLACE FUNCTION public.fn_atualizar_saldo_conta(p_conta_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE v_saldo NUMERIC;
BEGIN
  SELECT COALESCE(SUM(CASE WHEN tipo = 'entrada' THEN valor ELSE -valor END), 0) INTO v_saldo
  FROM movimentacoes_financeiras
  WHERE conta_financeira_id = p_conta_id;

  UPDATE contas_financeiras
  SET saldo_atual = v_saldo, atualizado_em = NOW()
  WHERE id = p_conta_id;
END;
$function$;

-- 5. CONFIGURAÇÃO DE RLS (SEGURANÇA)
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenants_select ON public.tenants FOR SELECT USING (id = ANY (get_my_tenant_ids()));

ALTER TABLE public.lotes ENABLE ROW LEVEL SECURITY;
CREATE POLICY lotes_tenant ON public.lotes FOR ALL USING (tenant_id = ANY (get_my_tenant_ids()));

ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;
CREATE POLICY vendas_tenant ON public.vendas FOR ALL USING (tenant_id = ANY (get_my_tenant_ids()));

ALTER TABLE public.custos ENABLE ROW LEVEL SECURITY;
CREATE POLICY custos_tenant ON public.custos FOR ALL USING (tenant_id = ANY (get_my_tenant_ids()));

-- O script completo continua com as views e triggers exportados...
