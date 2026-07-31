// Escrito a mano para reflejar supabase/migrations/20260731000000_init_agencias_profiles_roles.sql.
// Reemplazar por la salida real de `supabase gen types typescript` en cuanto
// el proyecto quede enlazado con el Supabase CLI.

export type UserRole = "freelancer" | "asesor" | "admin_agencia" | "super_admin";

export interface Database {
  public: {
    Tables: {
      agencias: {
        Row: {
          id: string;
          tipo: "agencia" | "freelancer";
          nombre: string;
          activo: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          tipo: "agencia" | "freelancer";
          nombre: string;
          activo?: boolean;
          created_at?: string;
        };
        Update: Partial<Database["public"]["Tables"]["agencias"]["Insert"]>;
      };
      profiles: {
        Row: {
          id: string;
          agencia_id: string;
          role: UserRole;
          nombre: string;
          activo: boolean;
          created_at: string;
        };
        Insert: {
          id: string;
          agencia_id: string;
          role: UserRole;
          nombre: string;
          activo?: boolean;
          created_at?: string;
        };
        Update: Partial<Database["public"]["Tables"]["profiles"]["Insert"]>;
      };
    };
    Views: Record<string, never>;
    Functions: {
      current_agencia_id: {
        Args: Record<string, never>;
        Returns: string;
      };
      current_user_role: {
        Args: Record<string, never>;
        Returns: UserRole;
      };
    };
    Enums: {
      user_role: UserRole;
    };
  };
}
